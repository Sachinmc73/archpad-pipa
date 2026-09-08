/*
 * rear-camera-test.c - Test capture from OV13B10 rear camera via CSIPHY1 -> CSID0 -> VFE0
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

#ifndef MEDIA_BUS_FMT_SGRBG10_1X10
#define MEDIA_BUS_FMT_SGRBG10_1X10 0x300a
#endif
#ifndef V4L2_PIX_FMT_SGRBG10P
#define V4L2_PIX_FMT_SGRBG10P v4l2_fourcc('p', 'G', 'B', 'A')
#endif

#define NUM_BUFFERS 4

struct buffer { void *start; size_t length; };

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
    if (ret < 0) {
        fprintf(stderr, "S_FMT %s pad %u: %s\n", path, pad, strerror(errno));
    } else {
        printf("  %s pad %u: %ux%u (0x%04x)\n", path, pad, fmt.format.width, fmt.format.height, fmt.format.code);
    }
    close(fd);
    return ret;
}

int main()
{
    int media_fd = open("/dev/media0", O_RDWR | O_CLOEXEC);
    if (media_fd < 0) { perror("open /dev/media0"); return 1; }

    printf("[1] Resetting links and configuring CSIPHY1 -> CSID0 -> VFE0_RDI0...\n");
    // csiphy4:1 -> csid0:0 (disable)
    setup_link(media_fd, 13, 1, 19, 0, 0);
    // csiphy1:1 -> csid0:0 (enable) (entity 4:1 -> 19:0)
    setup_link(media_fd, 4, 1, 19, 0, MEDIA_LNK_FL_ENABLED);
    // csid0:1 -> vfe0_rdi0:0 (enable) (entity 19:1 -> 43:0)
    setup_link(media_fd, 19, 1, 43, 0, MEDIA_LNK_FL_ENABLED);

    printf("[2] Setting formats for 4208x3120 SGRBG10...\n");
    __u32 w = 4208, h = 3120, code = MEDIA_BUS_FMT_SGRBG10_1X10;
    set_subdev_fmt("/dev/v4l-subdev24", 0, w, h, code);
    set_subdev_fmt("/dev/v4l-subdev1", 0, w, h, code);
    set_subdev_fmt("/dev/v4l-subdev1", 1, w, h, code);
    set_subdev_fmt("/dev/v4l-subdev6", 0, w, h, code);
    set_subdev_fmt("/dev/v4l-subdev6", 1, w, h, code);
    set_subdev_fmt("/dev/v4l-subdev10", 0, w, h, code);
    set_subdev_fmt("/dev/v4l-subdev10", 1, w, h, code);

    printf("[3] Setting /dev/video0 format...\n");
    int video_fd = open("/dev/video0", O_RDWR | O_CLOEXEC);
    if (video_fd < 0) { perror("open /dev/video0"); return 1; }

    struct v4l2_format vfmt = {
        .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
        .fmt.pix_mp = {
            .width = w, .height = h,
            .pixelformat = V4L2_PIX_FMT_SGRBG10P,
            .field = V4L2_FIELD_NONE,
            .num_planes = 1,
        },
    };
    if (ioctl(video_fd, VIDIOC_S_FMT, &vfmt) < 0) {
        perror("VIDIOC_S_FMT"); close(video_fd); return 1;
    }
    printf("  Video fmt: %ux%u bytesperline=%u sizeimage=%u\n",
           vfmt.fmt.pix_mp.width, vfmt.fmt.pix_mp.height,
           vfmt.fmt.pix_mp.plane_fmt[0].bytesperline,
           vfmt.fmt.pix_mp.plane_fmt[0].sizeimage);

    printf("[4] Queueing buffers...\n");
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

    printf("[5] Starting STREAMON...\n");
    enum v4l2_buf_type type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
    if (ioctl(video_fd, VIDIOC_STREAMON, &type) < 0) {
        perror("VIDIOC_STREAMON"); close(video_fd); return 1;
    }

    int mem_fd = open("/dev/mem", O_RDONLY | O_SYNC);
    if (mem_fd >= 0) {
        void *map = mmap(NULL, 0x1000, PROT_READ, MAP_SHARED, mem_fd, 0x0ac6c000);
        if (map != MAP_FAILED) {
            int dfd = open("/tmp/csiphy1_stream.bin", O_WRONLY | O_CREAT | O_TRUNC, 0644);
            if (dfd >= 0) {
                write(dfd, map, 0x1000);
                close(dfd);
                printf("  CSIPHY1 registers (0x1000 bytes) dumped to /tmp/csiphy1_stream.bin\n");
            }
            printf("  CSIPHY1 status registers (0x0ac6c8b0+):\n");
            for (int n = 0; n < 16; n++) {
                volatile uint32_t *r = (volatile uint32_t *)((char *)map + 0x8b0 + n * 4);
                printf("    STATUS%02d [0x%03x] = 0x%08x\n", n, 0x8b0 + n * 4, *r);
            }
            munmap(map, 0x1000);
        }
        close(mem_fd);
    }

    printf("  Waiting for frame (timeout 3000 ms)...\n");
    struct pollfd pfd = { .fd = video_fd, .events = POLLIN };
    int ret = poll(&pfd, 1, 3000);
    if (ret > 0) {
        struct v4l2_plane planes[1] = {0};
        struct v4l2_buffer buf = {
            .type = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE,
            .memory = V4L2_MEMORY_MMAP,
            .length = 1, .m.planes = planes,
        };
        ioctl(video_fd, VIDIOC_DQBUF, &buf);
        printf("  SUCCESS! Frame captured! seq=%u bytesused=%u\n", buf.sequence, planes[0].bytesused);
    } else if (ret == 0) {
        printf("  TIMEOUT! No frame from rear camera either!\n");
    } else {
        perror("poll");
    }

    ioctl(video_fd, VIDIOC_STREAMOFF, &type);
    for (int i = 0; i < NUM_BUFFERS; i++) munmap(buffers[i].start, buffers[i].length);
    close(video_fd);

    setup_link(media_fd, 4, 1, 19, 0, 0);
    setup_link(media_fd, 19, 1, 43, 0, 0);
    close(media_fd);
    return 0;
}
