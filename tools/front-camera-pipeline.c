/*
 * front-camera-pipeline.c - Qualcomm CAMSS pipeline setup and frame capture test
 * for Xiaomi Pad 6 (pipa) front camera (HI846W).
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

#include <linux/media.h>
#include <linux/types.h>
#include <linux/v4l2-mediabus.h>
#include <linux/v4l2-subdev.h>
#include <linux/videodev2.h>
#include <stdint.h>

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

static int find_dev_node(dev_t dev, char *out, size_t outlen)
{
    char path[64];
    struct stat st;

    for (int i = 0; i < 64; i++) {
        snprintf(path, sizeof(path), "/dev/v4l-subdev%d", i);
        if (stat(path, &st) == 0 && st.st_rdev == dev) {
            strncpy(out, path, outlen);
            return 0;
        }
    }
    for (int i = 0; i < 64; i++) {
        snprintf(path, sizeof(path), "/dev/video%d", i);
        if (stat(path, &st) == 0 && st.st_rdev == dev) {
            strncpy(out, path, outlen);
            return 0;
        }
    }
    return -1;
}

static int setup_link(int media_fd, __u32 src_ent, __u16 src_pad,
                      __u32 sink_ent, __u16 sink_pad, __u32 flags)
{
    struct media_link_desc link = {
        .source = { .entity = src_ent, .index = src_pad },
        .sink   = { .entity = sink_ent, .index = sink_pad },
        .flags  = flags,
    };
    if (ioctl(media_fd, MEDIA_IOC_SETUP_LINK, &link) < 0) {
        perror("MEDIA_IOC_SETUP_LINK");
        return -1;
    }
    return 0;
}

static int set_subdev_format(const char *path, __u16 pad, __u32 width,
                             __u32 height, __u32 code)
{
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open %s: %s\n", path, strerror(errno));
        return -1;
    }

    struct v4l2_subdev_format fmt = {
        .which = V4L2_SUBDEV_FORMAT_ACTIVE,
        .pad = pad,
        .format = {
            .width = width,
            .height = height,
            .code = code,
            .field = V4L2_FIELD_NONE,
            .colorspace = V4L2_COLORSPACE_RAW,
        },
    };

    if (ioctl(fd, VIDIOC_SUBDEV_S_FMT, &fmt) < 0) {
        fprintf(stderr, "VIDIOC_SUBDEV_S_FMT on %s (pad %u): %s\n",
                path, pad, strerror(errno));
        close(fd);
        return -1;
    }

    printf("  %s (pad %u): set %ux%u code=0x%04x -> got %ux%u code=0x%04x\n",
           path, pad, width, height, code,
           fmt.format.width, fmt.format.height, fmt.format.code);

    close(fd);
    return 0;
}

static int set_subdev_ctrl(const char *path, __u32 id, __s32 val)
{
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) {
        fprintf(stderr, "open %s: %s\n", path, strerror(errno));
        return -1;
    }

    struct v4l2_control ctrl = {
        .id = id,
        .value = val,
    };

    if (ioctl(fd, VIDIOC_S_CTRL, &ctrl) < 0) {
        fprintf(stderr, "VIDIOC_S_CTRL (id=0x%08x, val=%d) on %s: %s\n",
                id, val, path, strerror(errno));
        close(fd);
        return -1;
    }

    printf("  %s: set ctrl 0x%08x = %d\n", path, id, val);
    close(fd);
    return 0;
}

static void print_camss_irqs(const char *header)
{
    printf("%s\n", header);
    FILE *f = fopen("/proc/interrupts", "r");
    if (!f) return;
    char line[256];
    while (fgets(line, sizeof(line), f)) {
        if (strstr(line, "camss") || strstr(line, "cci")) {
            printf("    %s", line);
        }
    }
    fclose(f);
}

static void print_clock_status(void)
{
    FILE *f = popen("grep -E 'mclk3|csi4|ife_' /sys/kernel/debug/clk/clk_summary 2>/dev/null", "r");
    if (!f) return;
    char line[256];
    printf("  Clocks during stream:\n");
    while (fgets(line, sizeof(line), f)) {
        printf("    %s", line);
    }
    pclose(f);
}

static void print_csiphy_status(void)
{
    int fd = open("/dev/mem", O_RDONLY | O_SYNC);
    if (fd < 0) {
        printf("  Cannot open /dev/mem: %s\n", strerror(errno));
        return;
    }
    off_t target = 0x0ac72000;
    void *map_base = mmap(NULL, 0x1000, PROT_READ, MAP_SHARED, fd, target);
    if (map_base == MAP_FAILED) {
        printf("  Cannot mmap CSIPHY4 at 0x%lx: %s\n", (unsigned long)target, strerror(errno));
        close(fd);
        return;
    }
    printf("  CSIPHY4 status registers (0x0ac728b0+):\n");
    for (int n = 0; n < 16; n++) {
        volatile uint32_t *reg = (volatile uint32_t *)((char *)map_base + 0x8b0 + n * 4);
        printf("    STATUS%02d [0x%03x] = 0x%08x\n", n, 0x8b0 + n * 4, *reg);
    }
    munmap(map_base, 0x1000);
    close(fd);
}

static void usage(const char *prog)
{
    printf("usage: %s [options]\n"
           "Options:\n"
           "  --dev <media_dev>        Media device (default: /dev/media0)\n"
           "  --res <WxH>              Resolution: 1632x1224 (default), 3264x2448, 1280x720\n"
           "  --csid <0-3>             CSID to use: 0 (default), 1, 2, 3\n"
           "  --vfe <0-3>              VFE to use: 0, 1, 2, 3 (default: same as csid)\n"
           "  --dump-phy               Dump CSIPHY4 status registers during stream\n"
           "  --csid-tpg <pattern>     Enable CSID internal TPG (1=incrementing, 9=color bars, etc.)\n"
           "  --sensor-tpg <pattern>   Enable HI846 sensor test pattern (1=solid, 2=bars, etc.)\n"
           "  --timeout <ms>           Poll timeout in ms (default: 5000)\n"
           "  --frames <n>             Number of frames to capture (default: 1)\n"
           "  --help                   Show this help\n", prog);
}

int main(int argc, char **argv)
{
    const char *media_dev = "/dev/media0";
    __u32 width = 1632, height = 1224;
    int capture_frames = 1;
    int timeout_ms = 5000;
    int csid_num = 0;
    int vfe_num = -1;
    int dump_phy = 0;
    int csid_tpg = -1;
    int sensor_tpg = -1;

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--help") == 0) {
            usage(argv[0]);
            return 0;
        } else if (strcmp(argv[i], "--dev") == 0 && i + 1 < argc) {
            media_dev = argv[++i];
        } else if (strcmp(argv[i], "--res") == 0 && i + 1 < argc) {
            sscanf(argv[++i], "%ux%u", &width, &height);
        } else if (strcmp(argv[i], "--csid") == 0 && i + 1 < argc) {
            csid_num = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--vfe") == 0 && i + 1 < argc) {
            vfe_num = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--dump-phy") == 0) {
            dump_phy = 1;
        } else if (strcmp(argv[i], "--csid-tpg") == 0 && i + 1 < argc) {
            csid_tpg = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--sensor-tpg") == 0 && i + 1 < argc) {
            sensor_tpg = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--timeout") == 0 && i + 1 < argc) {
            timeout_ms = atoi(argv[++i]);
        } else if (strcmp(argv[i], "--frames") == 0 && i + 1 < argc) {
            capture_frames = atoi(argv[++i]);
        } else {
            fprintf(stderr, "Unknown argument: %s\n", argv[i]);
            usage(argv[0]);
            return 1;
        }
    }

    if (vfe_num < 0) vfe_num = csid_num;

    printf("[1/5] Discovering CAMSS entities on %s...\n", media_dev);
    printf("  Configuration: res=%ux%u, csid_tpg=%d, sensor_tpg=%d, timeout=%dms, frames=%d\n",
           width, height, csid_tpg, sensor_tpg, timeout_ms, capture_frames);

    int media_fd = open(media_dev, O_RDWR | O_CLOEXEC);
    if (media_fd < 0) { perror("open media"); return 1; }

    struct media_device_info info = {0};
    if (ioctl(media_fd, MEDIA_IOC_DEVICE_INFO, &info) < 0) {
        perror("MEDIA_IOC_DEVICE_INFO"); close(media_fd); return 1;
    }
    printf("  driver=%s model=%s bus=%s\n", info.driver, info.model, info.bus_info);

    __u32 id_hi846 = 0, id_csiphy4 = 0;
    char path_hi846[64] = {0}, path_csiphy4[64] = {0};

    __u32 id_csid[4] = {0};
    char path_csid[4][64] = {{0}};

    __u32 id_vfe_rdi[4] = {0};
    char path_vfe_rdi[4][64] = {{0}};

    __u32 id_vfe_video[4] = {0};
    char path_vfe_video[4][64] = {{0}};

    struct media_entity_desc ent = {.id = MEDIA_ENT_ID_FLAG_NEXT};
    while (ioctl(media_fd, MEDIA_IOC_ENUM_ENTITIES, &ent) == 0) {
        char dev_path[64] = "none";
        if (ent.dev.major) {
            find_dev_node(makedev(ent.dev.major, ent.dev.minor), dev_path, sizeof(dev_path));
        }

        if (strstr(ent.name, "hi846") != NULL) {
            id_hi846 = ent.id;
            strncpy(path_hi846, dev_path, sizeof(path_hi846));
            printf("  Found sensor: entity=%u name='%s' dev='%s'\n", ent.id, ent.name, dev_path);
        } else if (strcmp(ent.name, "msm_csiphy4") == 0) {
            id_csiphy4 = ent.id;
            strncpy(path_csiphy4, dev_path, sizeof(path_csiphy4));
            printf("  Found CSIPHY: entity=%u name='%s' dev='%s'\n", ent.id, ent.name, dev_path);
        } else {
            for (int k = 0; k < 4; k++) {
                char target[32];
                snprintf(target, sizeof(target), "msm_csid%d", k);
                if (strcmp(ent.name, target) == 0) {
                    id_csid[k] = ent.id;
                    strncpy(path_csid[k], dev_path, sizeof(path_csid[k]));
                    printf("  Found CSID%d:   entity=%u name='%s' dev='%s'\n", k, ent.id, ent.name, dev_path);
                }
                snprintf(target, sizeof(target), "msm_vfe%d_rdi0", k);
                if (strcmp(ent.name, target) == 0) {
                    id_vfe_rdi[k] = ent.id;
                    strncpy(path_vfe_rdi[k], dev_path, sizeof(path_vfe_rdi[k]));
                    printf("  Found VFE%d RDI: entity=%u name='%s' dev='%s'\n", k, ent.id, ent.name, dev_path);
                }
                snprintf(target, sizeof(target), "msm_vfe%d_video0", k);
                if (strcmp(ent.name, target) == 0) {
                    id_vfe_video[k] = ent.id;
                    strncpy(path_vfe_video[k], dev_path, sizeof(path_vfe_video[k]));
                    printf("  Found Video%d:   entity=%u name='%s' dev='%s'\n", k, ent.id, ent.name, dev_path);
                }
            }
        }
        ent.id |= MEDIA_ENT_ID_FLAG_NEXT;
    }

    if (!id_csid[csid_num] || !id_vfe_rdi[vfe_num] || !id_vfe_video[vfe_num]) {
        fprintf(stderr, "Error: missing required CAMSS pipeline entities for CSID%d / VFE%d!\n",
                csid_num, vfe_num);
        close(media_fd);
        return 1;
    }

    printf("\nSelected pipeline: CSIPHY4 -> CSID%d (%s) -> VFE%d RDI0 (%s) -> Video%d (%s)\n",
           csid_num, path_csid[csid_num], vfe_num, path_vfe_rdi[vfe_num], vfe_num, path_vfe_video[vfe_num]);

    /* Reset existing links first on all CSIDs */
    for (int k = 0; k < 4; k++) {
        if (id_csid[k]) {
            setup_link(media_fd, id_csiphy4, 1, id_csid[k], 0, 0);
            for (int v = 0; v < 4; v++) {
                if (id_vfe_rdi[v]) setup_link(media_fd, id_csid[k], 1, id_vfe_rdi[v], 0, 0);
            }
        }
    }

    printf("\n[2/5] Configuring pipeline links in media controller...\n");
    if (csid_tpg >= 0) {
        printf("  CSID TPG mode requested (%d): disabling CSIPHY4 link\n", csid_tpg);
        if (set_subdev_ctrl(path_csid[csid_num], V4L2_CID_TEST_PATTERN, csid_tpg) < 0) {
            fprintf(stderr, "Failed to set CSID TPG control!\n");
            close(media_fd); return 1;
        }
    } else {
        printf("  Normal sensor mode: Link csiphy4:1 -> csid%d:0 (ENABLE)\n", csid_num);
        if (setup_link(media_fd, id_csiphy4, 1, id_csid[csid_num], 0, MEDIA_LNK_FL_ENABLED) < 0) {
            close(media_fd); return 1;
        }
        if (sensor_tpg >= 0) {
            printf("  Setting HI846 sensor test pattern to %d...\n", sensor_tpg);
            set_subdev_ctrl(path_hi846, V4L2_CID_TEST_PATTERN, sensor_tpg);
        }
    }

    printf("  Link: csid%d:1 -> vfe%d_rdi0:0 (ENABLE)\n", csid_num, vfe_num);
    if (setup_link(media_fd, id_csid[csid_num], 1, id_vfe_rdi[vfe_num], 0, MEDIA_LNK_FL_ENABLED) < 0) {
        close(media_fd); return 1;
    }
    printf("  Media links configured successfully.\n");

    #define path_csid0 path_csid[csid_num]
    #define path_vfe0_rdi0 path_vfe_rdi[vfe_num]
    #define path_video0 path_vfe_video[vfe_num]

    printf("\n[3/5] Setting subdevice and video formats (%ux%u Bayer SGBRG10)...\n", width, height);
    __u32 code = MEDIA_BUS_FMT_SGBRG10_1X10;

    if (csid_tpg < 0) {
        printf("  Configuring sensor %s...\n", path_hi846);
        if (set_subdev_format(path_hi846, 0, width, height, code) < 0) return 1;

        printf("  Configuring CSIPHY %s...\n", path_csiphy4);
        if (set_subdev_format(path_csiphy4, 0, width, height, code) < 0) return 1;
        if (set_subdev_format(path_csiphy4, 1, width, height, code) < 0) return 1;

        printf("  Configuring CSID sink %s (pad 0)...\n", path_csid0);
        if (set_subdev_format(path_csid0, 0, width, height, code) < 0) return 1;
    }

    printf("  Configuring CSID src %s (pad 1)...\n", path_csid0);
    if (set_subdev_format(path_csid0, 1, width, height, code) < 0) return 1;

    printf("  Configuring VFE RDI %s...\n", path_vfe0_rdi0);
    if (set_subdev_format(path_vfe0_rdi0, 0, width, height, code) < 0) return 1;
    if (set_subdev_format(path_vfe0_rdi0, 1, width, height, code) < 0) return 1;

    printf("  Opening video node %s...\n", path_video0);
    int video_fd = open(path_video0, O_RDWR | O_CLOEXEC);
    if (video_fd < 0) { perror("open video node"); return 1; }

    struct v4l2_format vfmt = {
        .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
        .fmt.pix_mp = {
            .width = width,
            .height = height,
            .pixelformat = V4L2_PIX_FMT_SGBRG10P,
            .field = V4L2_FIELD_NONE,
            .num_planes = 1,
        },
    };
    if (ioctl(video_fd, VIDIOC_S_FMT, &vfmt) < 0) {
        perror("VIDIOC_S_FMT on video node");
        close(video_fd); return 1;
    }
    printf("  Video node format set: %ux%u pixfmt=0x%08x bytesperline=%u sizeimage=%u\n",
           vfmt.fmt.pix_mp.width, vfmt.fmt.pix_mp.height,
           vfmt.fmt.pix_mp.pixelformat,
           vfmt.fmt.pix_mp.plane_fmt[0].bytesperline,
           vfmt.fmt.pix_mp.plane_fmt[0].sizeimage);

    printf("\n[4/5] Allocating and queueing %d DMA buffers...\n", NUM_BUFFERS);
    struct v4l2_requestbuffers req = {
        .count = NUM_BUFFERS,
        .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
        .memory = V4L2_MEMORY_MMAP,
    };
    if (ioctl(video_fd, VIDIOC_REQBUFS, &req) < 0) {
        perror("VIDIOC_REQBUFS"); close(video_fd); return 1;
    }

    struct buffer buffers[NUM_BUFFERS];
    for (int i = 0; i < NUM_BUFFERS; i++) {
        struct v4l2_plane planes[1] = {0};
        struct v4l2_buffer buf = {
            .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .memory = V4L2_MEMORY_MMAP,
            .index = i,
            .length = 1,
            .m.planes = planes,
        };
        if (ioctl(video_fd, VIDIOC_QUERYBUF, &buf) < 0) {
            perror("VIDIOC_QUERYBUF"); return 1;
        }
        buffers[i].length = planes[0].length;
        buffers[i].start = mmap(NULL, planes[0].length, PROT_READ | PROT_WRITE,
                                MAP_SHARED, video_fd, planes[0].m.mem_offset);
        if (buffers[i].start == MAP_FAILED) {
            perror("mmap"); return 1;
        }
        if (ioctl(video_fd, VIDIOC_QBUF, &buf) < 0) {
            perror("VIDIOC_QBUF"); return 1;
        }
    }
    printf("  %d buffers mapped and queued successfully (plane size: %zu bytes).\n",
           NUM_BUFFERS, buffers[0].length);

    print_camss_irqs("CAMSS interrupts before STREAMON:");

    printf("\n[5/5] Starting video stream (STREAMON)...\n");
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
    if (ioctl(video_fd, VIDIOC_STREAMON, &type) < 0) {
        perror("VIDIOC_STREAMON");
        close(video_fd);
        return 1;
    }
    printf("  STREAMON active. Waiting for frames (poll timeout: %d ms)...\n", timeout_ms);

    print_clock_status();
    if (dump_phy) print_csiphy_status();

    for (int frame = 0; frame < capture_frames; frame++) {
        struct pollfd pfd = { .fd = video_fd, .events = POLLIN };
        int ret = poll(&pfd, 1, timeout_ms);
        if (ret < 0) {
            perror("poll");
            break;
        }
        if (ret == 0) {
            fprintf(stderr, "  TIMEOUT: No frame ready within %d ms!\n", timeout_ms);
            if (dump_phy) print_csiphy_status();
            break;
        }

        struct v4l2_plane planes[1] = {0};
        struct v4l2_buffer buf = {
            .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .memory = V4L2_MEMORY_MMAP,
            .length = 1,
            .m.planes = planes,
        };
        if (ioctl(video_fd, VIDIOC_DQBUF, &buf) < 0) {
            perror("VIDIOC_DQBUF");
            break;
        }

        size_t bytesused = planes[0].bytesused;
        printf("  >>> FRAME %d CAPTURED! seq=%u timestamp=%ld.%06ld bytesused=%zu\n",
               frame + 1, buf.sequence, (long)buf.timestamp.tv_sec,
               (long)buf.timestamp.tv_usec, bytesused);

        /* Inspect pixel samples */
        const unsigned char *p = (const unsigned char *)buffers[buf.index].start;
        unsigned char min_val = 255, max_val = 0;
        unsigned long long sum = 0;
        size_t sample_count = bytesused > 0 ? bytesused : buffers[buf.index].length;
        for (size_t s = 0; s < sample_count; s++) {
            if (p[s] < min_val) min_val = p[s];
            if (p[s] > max_val) max_val = p[s];
            sum += p[s];
        }
        double mean_val = sample_count > 0 ? (double)sum / sample_count : 0;
        printf("  Frame stats: min=%u max=%u mean=%.2f (sample count=%zu)\n",
               min_val, max_val, mean_val, sample_count);

        char out_filename[64];
        snprintf(out_filename, sizeof(out_filename), "/tmp/frame-%d.raw", frame + 1);
        int out_fd = open(out_filename, O_WRONLY | O_CREAT | O_TRUNC, 0644);
        if (out_fd >= 0) {
            write(out_fd, buffers[buf.index].start, sample_count);
            close(out_fd);
            printf("  Saved raw frame to %s\n", out_filename);
        }

        /* Re-queue buffer */
        if (ioctl(video_fd, VIDIOC_QBUF, &buf) < 0) {
            perror("VIDIOC_QBUF re-queue");
            break;
        }
    }

    printf("\nStopping stream (STREAMOFF)...\n");
    if (ioctl(video_fd, VIDIOC_STREAMOFF, &type) < 0) {
        perror("VIDIOC_STREAMOFF");
    }

    print_camss_irqs("CAMSS interrupts after STREAMOFF:");

    for (int i = 0; i < NUM_BUFFERS; i++) {
        munmap(buffers[i].start, buffers[i].length);
    }
    close(video_fd);

    printf("Cleaning up media links...\n");
    setup_link(media_fd, id_csiphy4, 1, id_csid[csid_num], 0, 0);
    setup_link(media_fd, id_csid[csid_num], 1, id_vfe_rdi[vfe_num], 0, 0);
    if (csid_tpg >= 0) {
        set_subdev_ctrl(path_csid[csid_num], V4L2_CID_TEST_PATTERN, 0);
    }
    close(media_fd);

    printf("Done!\n");
    return 0;
}
