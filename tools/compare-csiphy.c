/*
 * compare-csiphy.c - Robust comparison of CSIPHY1 vs CSIPHY4
 */
#include <errno.h>
#include <fcntl.h>
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

#include <linux/media.h>
#include <linux/types.h>
#include <linux/v4l2-mediabus.h>
#include <linux/v4l2-subdev.h>
#include <linux/videodev2.h>

#define NUM_BUFFERS 4

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
    return ioctl(media_fd, MEDIA_IOC_SETUP_LINK, &link);
}

static int set_subdev_fmt(const char *path, __u16 pad, __u32 w, __u32 h, __u32 code)
{
    int fd = open(path, O_RDWR | O_CLOEXEC);
    if (fd < 0) return -1;
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

int main()
{
    int media_fd = open("/dev/media0", O_RDWR | O_CLOEXEC);
    if (media_fd < 0) { perror("open /dev/media0"); return 1; }

    int mem_fd = open("/dev/mem", O_RDONLY | O_SYNC);
    if (mem_fd < 0) { perror("open /dev/mem"); close(media_fd); return 1; }

    __u32 id_ov13 = 0, id_hi846 = 0, id_csiphy1 = 0, id_csiphy4 = 0;
    __u32 id_csid0 = 0, id_vfe0_rdi0 = 0, id_video0 = 0;
    char path_ov13[64] = {0}, path_hi846[64] = {0};
    char path_csiphy1[64] = {0}, path_csiphy4[64] = {0};
    char path_csid0[64] = {0}, path_vfe0_rdi0[64] = {0}, path_video0[64] = {0};

    struct media_entity_desc ent = {.id = MEDIA_ENT_ID_FLAG_NEXT};
    while (ioctl(media_fd, MEDIA_IOC_ENUM_ENTITIES, &ent) == 0) {
        char dev_path[64] = "none";
        if (ent.dev.major) {
            find_dev_node(makedev(ent.dev.major, ent.dev.minor), dev_path, sizeof(dev_path));
        }
        if (strstr(ent.name, "ov13b10")) { id_ov13 = ent.id; strncpy(path_ov13, dev_path, sizeof(path_ov13)); }
        else if (strstr(ent.name, "hi846")) { id_hi846 = ent.id; strncpy(path_hi846, dev_path, sizeof(path_hi846)); }
        else if (strcmp(ent.name, "msm_csiphy1") == 0) { id_csiphy1 = ent.id; strncpy(path_csiphy1, dev_path, sizeof(path_csiphy1)); }
        else if (strcmp(ent.name, "msm_csiphy4") == 0) { id_csiphy4 = ent.id; strncpy(path_csiphy4, dev_path, sizeof(path_csiphy4)); }
        else if (strcmp(ent.name, "msm_csid0") == 0) { id_csid0 = ent.id; strncpy(path_csid0, dev_path, sizeof(path_csid0)); }
        else if (strcmp(ent.name, "msm_vfe0_rdi0") == 0) { id_vfe0_rdi0 = ent.id; strncpy(path_vfe0_rdi0, dev_path, sizeof(path_vfe0_rdi0)); }
        else if (strcmp(ent.name, "msm_vfe0_video0") == 0) { id_video0 = ent.id; strncpy(path_video0, dev_path, sizeof(path_video0)); }
        ent.id |= MEDIA_ENT_ID_FLAG_NEXT;
    }

    printf("Entities discovered:\n");
    printf("  ov13b10:   ent=%u dev=%s\n", id_ov13, path_ov13);
    printf("  hi846:     ent=%u dev=%s\n", id_hi846, path_hi846);
    printf("  csiphy1:   ent=%u dev=%s\n", id_csiphy1, path_csiphy1);
    printf("  csiphy4:   ent=%u dev=%s\n", id_csiphy4, path_csiphy4);
    printf("  csid0:     ent=%u dev=%s\n", id_csid0, path_csid0);
    printf("  vfe0_rdi0: ent=%u dev=%s\n", id_vfe0_rdi0, path_vfe0_rdi0);
    printf("  video0:    ent=%u dev=%s\n\n", id_video0, path_video0);

    uint32_t phy1_regs[0x1000 / 4] = {0};
    uint32_t phy4_regs[0x1000 / 4] = {0};

    /* Phase 1: Capture CSIPHY1 registers during OV13B10 stream */
    printf("[1] Capturing CSIPHY1 registers during rear camera stream...\n");
    // Clear links
    setup_link(media_fd, id_csiphy4, 1, id_csid0, 0, 0);
    setup_link(media_fd, id_csiphy1, 1, id_csid0, 0, MEDIA_LNK_FL_ENABLED);
    setup_link(media_fd, id_csid0, 1, id_vfe0_rdi0, 0, MEDIA_LNK_FL_ENABLED);

    set_subdev_fmt(path_ov13, 0, 4208, 3120, 0x300a);
    set_subdev_fmt(path_csiphy1, 0, 4208, 3120, 0x300a);
    set_subdev_fmt(path_csiphy1, 1, 4208, 3120, 0x300a);
    set_subdev_fmt(path_csid0, 0, 4208, 3120, 0x300a);
    set_subdev_fmt(path_csid0, 1, 4208, 3120, 0x300a);
    set_subdev_fmt(path_vfe0_rdi0, 0, 4208, 3120, 0x300a);
    set_subdev_fmt(path_vfe0_rdi0, 1, 4208, 3120, 0x300a);

    int vfd = open(path_video0, O_RDWR | O_CLOEXEC);
    if (vfd >= 0) {
        struct v4l2_format vfmt = {
            .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .fmt.pix_mp = {
                .width = 4208, .height = 3120,
                .pixelformat = v4l2_fourcc('p', 'G', 'B', 'A'),
                .field = V4L2_FIELD_NONE, .num_planes = 1,
            },
        };
        ioctl(vfd, VIDIOC_S_FMT, &vfmt);
        struct v4l2_requestbuffers req = {
            .count = NUM_BUFFERS, .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .memory = V4L2_MEMORY_MMAP,
        };
        ioctl(vfd, VIDIOC_REQBUFS, &req);
        void *bufs[NUM_BUFFERS];
        size_t buflen = 0;
        for (int i = 0; i < NUM_BUFFERS; i++) {
            struct v4l2_plane planes[1] = {0};
            struct v4l2_buffer buf = {
                .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
                .memory = V4L2_MEMORY_MMAP, .index = i, .length = 1, .m.planes = planes,
            };
            ioctl(vfd, VIDIOC_QUERYBUF, &buf);
            buflen = planes[0].length;
            bufs[i] = mmap(NULL, planes[0].length, PROT_READ | PROT_WRITE,
                           MAP_SHARED, vfd, planes[0].m.mem_offset);
            ioctl(vfd, VIDIOC_QBUF, &buf);
        }
        enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
        if (ioctl(vfd, VIDIOC_STREAMON, &type) == 0) {
            usleep(50000);
            void *map1 = mmap(NULL, 0x1000, PROT_READ, MAP_SHARED, mem_fd, 0x0ac6c000);
            if (map1 != MAP_FAILED) {
                for (int i = 0; i < 0x1000 / 4; i++) {
                    phy1_regs[i] = *(volatile uint32_t *)((char *)map1 + i * 4);
                }
                munmap(map1, 0x1000);
                printf("  CSIPHY1 registers captured successfully during stream!\n");
            }
            ioctl(vfd, VIDIOC_STREAMOFF, &type);
        } else {
            perror("STREAMON CSIPHY1");
        }
        for (int i = 0; i < NUM_BUFFERS; i++) munmap(bufs[i], buflen);
        close(vfd);
    }

    /* Reset links */
    setup_link(media_fd, id_csiphy1, 1, id_csid0, 0, 0);

    /* Phase 2: Capture CSIPHY4 registers during HI846 stream */
    printf("\n[2] Capturing CSIPHY4 registers during front camera stream...\n");
    setup_link(media_fd, id_csiphy4, 1, id_csid0, 0, MEDIA_LNK_FL_ENABLED);
    setup_link(media_fd, id_csid0, 1, id_vfe0_rdi0, 0, MEDIA_LNK_FL_ENABLED);

    set_subdev_fmt(path_hi846, 0, 3264, 2448, 0x300e);
    set_subdev_fmt(path_csiphy4, 0, 3264, 2448, 0x300e);
    set_subdev_fmt(path_csiphy4, 1, 3264, 2448, 0x300e);
    set_subdev_fmt(path_csid0, 0, 3264, 2448, 0x300e);
    set_subdev_fmt(path_csid0, 1, 3264, 2448, 0x300e);
    set_subdev_fmt(path_vfe0_rdi0, 0, 3264, 2448, 0x300e);
    set_subdev_fmt(path_vfe0_rdi0, 1, 3264, 2448, 0x300e);

    vfd = open(path_video0, O_RDWR | O_CLOEXEC);
    if (vfd >= 0) {
        struct v4l2_format vfmt = {
            .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .fmt.pix_mp = {
                .width = 3264, .height = 2448,
                .pixelformat = v4l2_fourcc('p', 'G', 'A', 'A'),
                .field = V4L2_FIELD_NONE, .num_planes = 1,
            },
        };
        ioctl(vfd, VIDIOC_S_FMT, &vfmt);
        struct v4l2_requestbuffers req = {
            .count = NUM_BUFFERS, .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .memory = V4L2_MEMORY_MMAP,
        };
        ioctl(vfd, VIDIOC_REQBUFS, &req);
        void *bufs[NUM_BUFFERS];
        size_t buflen = 0;
        for (int i = 0; i < NUM_BUFFERS; i++) {
            struct v4l2_plane planes[1] = {0};
            struct v4l2_buffer buf = {
                .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
                .memory = V4L2_MEMORY_MMAP, .index = i, .length = 1, .m.planes = planes,
            };
            ioctl(vfd, VIDIOC_QUERYBUF, &buf);
            buflen = planes[0].length;
            bufs[i] = mmap(NULL, planes[0].length, PROT_READ | PROT_WRITE,
                           MAP_SHARED, vfd, planes[0].m.mem_offset);
            ioctl(vfd, VIDIOC_QBUF, &buf);
        }
        enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
        if (ioctl(vfd, VIDIOC_STREAMON, &type) == 0) {
            usleep(50000);
            void *map4 = mmap(NULL, 0x1000, PROT_READ, MAP_SHARED, mem_fd, 0x0ac72000);
            if (map4 != MAP_FAILED) {
                for (int i = 0; i < 0x1000 / 4; i++) {
                    phy4_regs[i] = *(volatile uint32_t *)((char *)map4 + i * 4);
                }
                munmap(map4, 0x1000);
                printf("  CSIPHY4 registers captured successfully during stream!\n");
            }
            ioctl(vfd, VIDIOC_STREAMOFF, &type);
        } else {
            perror("STREAMON CSIPHY4");
        }
        for (int i = 0; i < NUM_BUFFERS; i++) munmap(bufs[i], buflen);
        close(vfd);
    }

    setup_link(media_fd, id_csiphy4, 1, id_csid0, 0, 0);
    close(media_fd);
    close(mem_fd);

    /* Phase 3: Compare registers */
    printf("\n=== Register Differences between CSIPHY1 (rear) and CSIPHY4 (front) ===\n");
    int diff_count = 0;
    for (int i = 0; i < 0x1000 / 4; i++) {
        uint32_t offset = i * 4;
        uint32_t v1 = phy1_regs[i];
        uint32_t v4 = phy4_regs[i];
        if (v1 != v4) {
            diff_count++;
            const char *sec = "UNKNOWN";
            if (offset < 0x200) sec = "Lane 0";
            else if (offset < 0x400) sec = "Lane 1";
            else if (offset < 0x600) sec = "Lane 2";
            else if (offset < 0x700) sec = "Lane 3";
            else if (offset < 0x800) sec = "Clk Lane";
            else if (offset < 0x900) sec = "Common/Ctrl";
            else if (offset < 0xa00) sec = "Top/Misc 1";
            else if (offset < 0xb00) sec = "Top/Misc 2";
            else if (offset < 0xd00) sec = "Top/Misc 3";

            printf("  [0x%03x] (%-11s): CSIPHY1 = 0x%08x, CSIPHY4 = 0x%08x\n",
                   offset, sec, v1, v4);
        }
    }
    printf("\nTotal differences: %d / 1024 registers\n", diff_count);
    return 0;
}
