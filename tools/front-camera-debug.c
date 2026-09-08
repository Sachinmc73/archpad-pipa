/*
 * front-camera-debug.c - Direct hardware & I2C diagnostic tool for Xiaomi Pad 6 front camera
 * Tests Chromatix register sequences and CSIPHY4 status live during streamon.
 */
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ioctl.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <sys/sysmacros.h>
#include <sys/types.h>
#include <unistd.h>
#include <stdint.h>

#include <linux/i2c.h>
#include <linux/i2c-dev.h>
#include <linux/media.h>
#include <linux/types.h>
#include <linux/v4l2-mediabus.h>
#include <linux/v4l2-subdev.h>
#include <linux/videodev2.h>

#include "vendor-hi846-regs.h"

#ifndef MEDIA_BUS_FMT_SGBRG10_1X10
#define MEDIA_BUS_FMT_SGBRG10_1X10 0x300e
#endif

#ifndef V4L2_PIX_FMT_SGBRG10P
#define V4L2_PIX_FMT_SGBRG10P v4l2_fourcc('p', 'G', 'A', 'A')
#endif

#define NUM_BUFFERS 4

struct buffer {
    void *start;
    size_t length;
};

static int i2c_read_reg_16(int fd, uint16_t reg, uint16_t *val)
{
    uint8_t out[2] = { reg >> 8, reg & 0xff };
    uint8_t in[2] = { 0, 0 };
    struct i2c_msg msgs[2] = {
        { .addr = 0x20, .flags = 0, .len = 2, .buf = out },
        { .addr = 0x20, .flags = I2C_M_RD, .len = 2, .buf = in },
    };
    struct i2c_rdwr_ioctl_data rdwr = { .msgs = msgs, .nmsgs = 2 };
    if (ioctl(fd, I2C_RDWR, &rdwr) < 0) {
        return -1;
    }
    *val = (in[0] << 8) | in[1];
    return 0;
}

static int i2c_write_reg_16(int fd, uint16_t reg, uint16_t val)
{
    uint8_t buf[4] = { reg >> 8, reg & 0xff, val >> 8, val & 0xff };
    struct i2c_msg msg = {
        .addr = 0x20, .flags = 0, .len = 4, .buf = buf
    };
    struct i2c_rdwr_ioctl_data rdwr = { .msgs = &msg, .nmsgs = 1 };
    if (ioctl(fd, I2C_RDWR, &rdwr) < 0) {
        return -1;
    }
    return 0;
}


static void clear_csiphy_status(void *csiphy_base)
{
    printf("  [Clearing CSIPHY4 status bits...]\n");
    // Write status values to COMMON_CTRL(22..32) at offset 0x858
    for (int i = 0; i < 11; i++) {
        volatile uint32_t *stat = (volatile uint32_t *)((char *)csiphy_base + 0x8b0 + i * 4);
        volatile uint32_t *ctrl = (volatile uint32_t *)((char *)csiphy_base + 0x800 + (22 + i) * 4);
        *ctrl = *stat;
    }
    // Toggle IRQ_CLEAR_CMD at COMMON_CTRL(10) (offset 0x828)
    volatile uint32_t *cmd = (volatile uint32_t *)((char *)csiphy_base + 0x800 + 10 * 4);
    *cmd = 1;
    *cmd = 0;
    // Clear COMMON_CTRL(22..32)
    for (int i = 0; i < 11; i++) {
        volatile uint32_t *ctrl = (volatile uint32_t *)((char *)csiphy_base + 0x800 + (22 + i) * 4);
        *ctrl = 0;
    }
}

static void print_csiphy_status(void *csiphy_base, const char *label)
{
    printf("  [CSIPHY4 %s] Status registers (0x0ac728b0+):\n", label);
    for (int n = 0; n < 12; n++) {
        volatile uint32_t *r = (volatile uint32_t *)((char *)csiphy_base + 0x8b0 + n * 4);
        printf("    STATUS%02d [0x%03x] = 0x%08x\n", n, 0x8b0 + n * 4, *r);
    }
}

static int setup_link(int media_fd, __u32 src_ent, __u16 src_pad,
                      __u32 sink_ent, __u16 sink_pad, __u32 flags)
{
    struct media_link_desc link = {
        .source = { .entity = src_ent, .index = src_pad },
        .sink   = { .entity = sink_ent, .index = sink_pad },
        .flags  = flags,
    };
    return ioctl(media_fd, MEDIA_IOC_SETUP_LINK, &link);
}

static int set_subdev_fmt(const char *path, __u16 pad, __u32 w, __u32 h, __u32 code)
{
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) { perror(path); return -1; }
    struct v4l2_subdev_format fmt = {
        .which = V4L2_SUBDEV_FORMAT_ACTIVE,
        .pad = pad,
        .format = {
            .width = w, .height = h, .code = code,
            .field = V4L2_FIELD_NONE, .colorspace = V4L2_COLORSPACE_RAW,
        },
    };
    int ret = ioctl(fd, VIDIOC_SUBDEV_S_FMT, &fmt);
    close(fd);
    return ret;
}

int main(int argc, char **argv)
{
    int apply_vendor_init = 0;
    int apply_vendor_mode0 = 0;
    int write_streamon_word = 1;
    int sweep_settle = 0;
    int two_lane = 0;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--full-vendor") == 0) {
            apply_vendor_init = 1;
            apply_vendor_mode0 = 1;
        } else if (strcmp(argv[i], "--init-only") == 0) {
            apply_vendor_init = 1;
        } else if (strcmp(argv[i], "--mode0-only") == 0) {
            apply_vendor_mode0 = 1;
        } else if (strcmp(argv[i], "--no-streamon-word") == 0) {
            write_streamon_word = 0;
        } else if (strcmp(argv[i], "--sweep-settle") == 0) {
            sweep_settle = 1;
        } else if (strcmp(argv[i], "--two-lane") == 0) {
            two_lane = 1;
        }
    }

    printf("=== HI846 / CSIPHY4 Live Diagnostic Test ===\n");
    printf("Options: vendor_init=%d, vendor_mode0=%d, write_streamon_word=%d, sweep_settle=%d, two_lane=%d\n\n",
           apply_vendor_init, apply_vendor_mode0, write_streamon_word, sweep_settle, two_lane);

    /* 1. Open /dev/mem to access CSIPHY4 registers */
    int mem_fd = open("/dev/mem", O_RDWR | O_SYNC);
    if (mem_fd < 0) { perror("open /dev/mem"); return 1; }
    void *csiphy_base = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, 0x0ac72000);
    if (csiphy_base == MAP_FAILED) { perror("mmap csiphy4"); close(mem_fd); return 1; }

    /* 2. Configure media pipeline: CSIPHY4 (13:1) -> CSID0 (19:0) -> VFE0_RDI0 (43:0) */
    int media_fd = open("/dev/media0", O_RDWR | O_CLOEXEC);
    if (media_fd < 0) { perror("open /dev/media0"); return 1; }

    // Disable rear camera link if active
    setup_link(media_fd, 4, 1, 19, 0, 0);
    // Enable front camera link
    setup_link(media_fd, 13, 1, 19, 0, MEDIA_LNK_FL_ENABLED);
    setup_link(media_fd, 19, 1, 43, 0, MEDIA_LNK_FL_ENABLED);

    /* 3. Set subdev formats for 3264x2448 SGBRG10 */
    __u32 w = 3264, h = 2448, code = MEDIA_BUS_FMT_SGBRG10_1X10;
    set_subdev_fmt("/dev/v4l-subdev25", 0, w, h, code); // hi846
    set_subdev_fmt("/dev/v4l-subdev4", 0, w, h, code);  // csiphy4 sink
    set_subdev_fmt("/dev/v4l-subdev4", 1, w, h, code);  // csiphy4 src
    set_subdev_fmt("/dev/v4l-subdev6", 0, w, h, code);  // csid0 sink
    set_subdev_fmt("/dev/v4l-subdev6", 1, w, h, code);  // csid0 src
    set_subdev_fmt("/dev/v4l-subdev10", 0, w, h, code); // vfe0_rdi0 sink
    set_subdev_fmt("/dev/v4l-subdev10", 1, w, h, code); // vfe0_rdi0 src

    /* 4. Configure video device */
    int video_fd = open("/dev/video0", O_RDWR | O_CLOEXEC);
    if (video_fd < 0) { perror("open /dev/video0"); return 1; }

    struct v4l2_format vfmt = {
        .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
        .fmt.pix_mp = {
            .width = w, .height = h,
            .pixelformat = V4L2_PIX_FMT_SGBRG10P,
            .field = V4L2_FIELD_NONE,
            .num_planes = 1,
        },
    };
    if (ioctl(video_fd, VIDIOC_S_FMT, &vfmt) < 0) { perror("VIDIOC_S_FMT"); }

    struct v4l2_requestbuffers req = {
        .count = NUM_BUFFERS,
        .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
        .memory = V4L2_MEMORY_MMAP,
    };
    ioctl(video_fd, VIDIOC_REQBUFS, &req);

    struct buffer buffers[NUM_BUFFERS];
    for (int i = 0; i < NUM_BUFFERS; i++) {
        struct v4l2_plane planes[1] = {0};
        struct v4l2_buffer buf = {
            .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .memory = V4L2_MEMORY_MMAP,
            .index = i, .length = 1, .m.planes = planes,
        };
        ioctl(video_fd, VIDIOC_QUERYBUF, &buf);
        buffers[i].length = planes[0].length;
        buffers[i].start = mmap(NULL, planes[0].length, PROT_READ | PROT_WRITE,
                                MAP_SHARED, video_fd, planes[0].m.mem_offset);
        ioctl(video_fd, VIDIOC_QBUF, &buf);
    }

    /* 5. Start STREAMON (powers up sensor, MCLK3 running, CSIPHY4 active) */
    printf("[1] Starting STREAMON...\n");
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
    if (ioctl(video_fd, VIDIOC_STREAMON, &type) < 0) {
        perror("VIDIOC_STREAMON");
        return 1;
    }

    print_csiphy_status(csiphy_base, "BASELINE (immediately after kernel STREAMON)");
    int dfd = open("/tmp/csiphy4_stream.bin", O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (dfd >= 0) {
        write(dfd, csiphy_base, 0x1000);
        close(dfd);
        printf("  CSIPHY4 registers (0x1000 bytes) dumped to /tmp/csiphy4_stream.bin\n");
    }

    /* 6. Open /dev/i2c-23 and communicate with HI846 */
    int i2c_fd = open("/dev/i2c-23", O_RDWR);
    if (i2c_fd < 0) {
        perror("open /dev/i2c-23");
    } else {
        uint16_t chip_id = 0;
        if (i2c_read_reg_16(i2c_fd, 0x0f16, &chip_id) == 0) {
            printf("\n[2] I2C direct read 0x0f16 (Chip ID) = 0x%04x (SUCCESS!)\n", chip_id);
        } else {
            printf("\n[2] I2C direct read 0x0f16 FAILED: %s\n", strerror(errno));
        }

        uint16_t reg_0a00 = 0;
        i2c_read_reg_16(i2c_fd, 0x0a00, &reg_0a00);
        printf("    I2C read 0x0a00 (MODE_SELECT) before modification = 0x%04x\n", reg_0a00);

        uint16_t reg_004c = 0;
        i2c_read_reg_16(i2c_fd, 0x004c, &reg_004c);
        printf("    I2C read 0x004c (TG_ENABLE) before modification = 0x%04x\n", reg_004c);

        if (apply_vendor_init) {
            printf("\n[3] Writing complete 557 vendor initSettings registers from Chromatix...\n");
            int write_err = 0;
            for (int i = 0; i < 557; i++) {
                if (i2c_write_reg_16(i2c_fd, vendor_init_regs[i].reg, vendor_init_regs[i].val) < 0) {
                    printf("    Error writing init reg[%d] 0x%04x = 0x%04x\n",
                           i, vendor_init_regs[i].reg, vendor_init_regs[i].val);
                    write_err++;
                    break;
                }
            }
            if (!write_err) printf("    All 557 init registers written successfully!\n");
        }

        if (apply_vendor_mode0) {
            printf("\n[4] Writing complete 50 vendor Mode 0 registers from Chromatix...\n");
            int write_err = 0;
            for (int i = 0; i < 50; i++) {
                if (i2c_write_reg_16(i2c_fd, vendor_mode0_regs[i].reg, vendor_mode0_regs[i].val) < 0) {
                    printf("    Error writing mode0 reg[%d] 0x%04x = 0x%04x\n",
                           i, vendor_mode0_regs[i].reg, vendor_mode0_regs[i].val);
                    write_err++;
                    break;
                }
            }
            if (!write_err) printf("    All 50 Mode 0 registers written successfully!\n");
        }

        if (write_streamon_word) {
            printf("\n[5] Sending STREAMON word 0x0a00 = 0x0100 (16-bit write)...\n");
            if (i2c_write_reg_16(i2c_fd, 0x0a00, 0x0100) == 0) {
                printf("    Written 0x0a00 = 0x0100 successfully!\n");
            } else {
                printf("    Failed to write 0x0a00 = 0x0100: %s\n", strerror(errno));
            }
            usleep(10000); // 10 ms
            i2c_read_reg_16(i2c_fd, 0x0a00, &reg_0a00);
            printf("    Readback 0x0a00 = 0x%04x\n", reg_0a00);
        }

        if (two_lane) {
            printf("\n[2-LANE] Configuring HI846 for 2 MIPI lanes (0x0902=0x431a, 0x000c=0x0022)...\n");
            i2c_write_reg_16(i2c_fd, 0x0902, 0x431a);
            i2c_write_reg_16(i2c_fd, 0x000c, 0x0022);
            uint16_t v0902 = 0;
            i2c_read_reg_16(i2c_fd, 0x0902, &v0902);
            printf("         Readback 0x0902 = 0x%04x\n", v0902);
        }

        close(i2c_fd);
    }

    void *csid0_base = mmap(NULL, 0x1000, PROT_READ | PROT_WRITE, MAP_SHARED, mem_fd, 0x0acb5000);
    if (two_lane) {
        printf("\n[2-LANE] Overriding CSIPHY4 and CSID0 registers for 2 data lanes...\n");
        volatile uint32_t *cmn_ctrl5 = (volatile uint32_t *)((char *)csiphy_base + 0x814);
        printf("  CSIPHY4 COMMON_CTRL5 before: 0x%08x\n", *cmn_ctrl5);
        *cmn_ctrl5 = 0x85; // Lane 0, Lane 1, Clk
        printf("  CSIPHY4 COMMON_CTRL5 after:  0x%08x\n", *cmn_ctrl5);

        volatile uint32_t *ln0_settle = (volatile uint32_t *)((char *)csiphy_base + 0x008);
        volatile uint32_t *ln1_settle = (volatile uint32_t *)((char *)csiphy_base + 0x208);
        volatile uint32_t *clk_settle = (volatile uint32_t *)((char *)csiphy_base + 0x708);
        *ln0_settle = 0x08;
        *ln1_settle = 0x08;
        *clk_settle = 0x08;
        printf("  CSIPHY4 settle count set to 0x08\n");

        if (csid0_base != MAP_FAILED) {
            volatile uint32_t *rx_cfg0 = (volatile uint32_t *)((char *)csid0_base + 0x300);
            printf("  CSID0 CSI2_RX_CFG0 before: 0x%08x\n", *rx_cfg0);
            *rx_cfg0 = 0x00400101; // 2 active lanes, lane_assign 0x10, csiphy_id 4
            printf("  CSID0 CSI2_RX_CFG0 after:  0x%08x\n", *rx_cfg0);

            volatile uint32_t *csid_irq_clr = (volatile uint32_t *)((char *)csid0_base + 0x228);
            *csid_irq_clr = 0xffffffff;
            volatile uint32_t *csid_rdi_clr = (volatile uint32_t *)((char *)csid0_base + 0x248);
            *csid_rdi_clr = 0xffffffff;
        }
    }

    print_csiphy_status(csiphy_base, "AFTER REGISTER CONFIGURATION");
    clear_csiphy_status(csiphy_base);
    print_csiphy_status(csiphy_base, "AFTER CLEAR");

    if (sweep_settle) {
        printf("\n[6] Sweeping CSIPHY4 settle count (4 to 32)...\n");
        volatile uint32_t *ln0_settle = (volatile uint32_t *)((char *)csiphy_base + 0x008);
        volatile uint32_t *ln1_settle = (volatile uint32_t *)((char *)csiphy_base + 0x208);
        volatile uint32_t *ln2_settle = (volatile uint32_t *)((char *)csiphy_base + 0x408);
        volatile uint32_t *ln3_settle = (volatile uint32_t *)((char *)csiphy_base + 0x608);
        volatile uint32_t *clk_settle = (volatile uint32_t *)((char *)csiphy_base + 0x708);
        printf("    Original settle count: ln0=0x%02x, clk=0x%02x\n", *ln0_settle, *clk_settle);

        for (uint32_t s = 4; s <= 32; s += 2) {
            *ln0_settle = s;
            *ln1_settle = s;
            *ln2_settle = s;
            *ln3_settle = s;
            *clk_settle = s;
            usleep(5000);
            volatile uint32_t *s01 = (volatile uint32_t *)((char *)csiphy_base + 0x8b4);
            volatile uint32_t *s03 = (volatile uint32_t *)((char *)csiphy_base + 0x8bc);
            volatile uint32_t *s09 = (volatile uint32_t *)((char *)csiphy_base + 0x8d4);
            printf("    settle=0x%02x: STATUS01=0x%02x, STATUS03=0x%02x, STATUS09=0x%02x\n",
                   s, *s01, *s03, *s09);
        }
    }

    /* 7. Poll for frame */
    printf("\n[7] Polling for frame on /dev/video0 (timeout 2000 ms)...\n");
    struct pollfd pfd = { .fd = video_fd, .events = POLLIN };
    int ret = poll(&pfd, 1, 2000);
    if (ret > 0) {
        struct v4l2_plane planes[1] = {0};
        struct v4l2_buffer buf = {
            .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .memory = V4L2_MEMORY_MMAP,
            .length = 1, .m.planes = planes,
        };
        if (ioctl(video_fd, VIDIOC_DQBUF, &buf) == 0) {
            printf("\n  >>> SUCCESS! FRAME CAPTURED! seq=%u bytesused=%u <<<\n",
                   buf.sequence, planes[0].bytesused);
        }
    } else if (ret == 0) {
        printf("  TIMEOUT: No frame received.\n");
        print_csiphy_status(csiphy_base, "AFTER TIMEOUT");
    } else {
        perror("poll");
    }

    /* 8. Stop stream */
    printf("\nStopping stream (STREAMOFF)...\n");
    ioctl(video_fd, VIDIOC_STREAMOFF, &type);
    for (int i = 0; i < NUM_BUFFERS; i++) munmap(buffers[i].start, buffers[i].length);
    close(video_fd);

    setup_link(media_fd, 13, 1, 19, 0, 0);
    setup_link(media_fd, 19, 1, 43, 0, 0);
    close(media_fd);

    munmap(csiphy_base, 0x1000);
    close(mem_fd);
    printf("Done!\n");
    return 0;
}
