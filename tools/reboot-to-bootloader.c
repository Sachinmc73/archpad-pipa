/* Minimal Linux RESTART2 helper for development devices. */
#include <linux/reboot.h>
#include <sys/syscall.h>
#include <unistd.h>

int main(void)
{
    sync();
    return syscall(SYS_reboot, LINUX_REBOOT_MAGIC1, LINUX_REBOOT_MAGIC2,
                   LINUX_REBOOT_CMD_RESTART2, "bootloader");
}
