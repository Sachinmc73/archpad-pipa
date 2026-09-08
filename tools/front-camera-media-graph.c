/* Read-only media entity/link inspection for the RAM-only probe image. */
#include <errno.h>
#include <fcntl.h>
#include <linux/media.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/ioctl.h>
#include <unistd.h>

int main(int argc, char **argv)
{
    if (argc != 2) {
        fprintf(stderr, "usage: %s /dev/mediaN\n", argv[0]);
        return 2;
    }
    int fd = open(argv[1], O_RDONLY | O_CLOEXEC);
    if (fd < 0) { perror("open"); return 1; }
    struct media_device_info info = {0};
    if (ioctl(fd, MEDIA_IOC_DEVICE_INFO, &info) < 0) {
        perror("MEDIA_IOC_DEVICE_INFO"); close(fd); return 1;
    }
    printf("driver=%s model=%s bus=%s\n", info.driver, info.model, info.bus_info);
    struct media_entity_desc entity = {.id = MEDIA_ENT_ID_FLAG_NEXT};
    while (ioctl(fd, MEDIA_IOC_ENUM_ENTITIES, &entity) == 0) {
        printf("entity=%u name=%s type=%x pads=%u links=%u dev=%u:%u\n",
               entity.id, entity.name, entity.type, entity.pads, entity.links,
               entity.dev.major, entity.dev.minor);
        struct media_links_enum links = {.entity = entity.id};
        links.pads = calloc(entity.pads ? entity.pads : 1, sizeof(*links.pads));
        links.links = calloc(entity.links ? entity.links : 1, sizeof(*links.links));
        if (!links.pads || !links.links) { perror("calloc"); return 1; }
        if (ioctl(fd, MEDIA_IOC_ENUM_LINKS, &links) < 0) {
            perror("MEDIA_IOC_ENUM_LINKS"); return 1;
        }
        for (unsigned i = 0; i < entity.links; i++)
            printf("  %u:%u -> %u:%u flags=%x\n",
                   links.links[i].source.entity, links.links[i].source.index,
                   links.links[i].sink.entity, links.links[i].sink.index,
                   links.links[i].flags);
        free(links.pads); free(links.links);
        entity.id |= MEDIA_ENT_ID_FLAG_NEXT;
    }
    int saved_errno = errno;
    close(fd);
    if (saved_errno != EINVAL) { errno = saved_errno; perror("ENUM_ENTITIES"); return 1; }
    return 0;
}
