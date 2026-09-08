# archpad-clock

The Xiaomi Pad 6 PMIC RTC is an always-running counter, but this device's
current firmware/device-tree combination exposes it with a 1972 base. When the
`rtc-pm8xxx` module probes, the kernel therefore moves the system clock back to
1972.

This package keeps the PMIC counter untouched. Once Linux has trustworthy
time, `archpad-clock-save` stores only the difference between that time and the
counter. Early on later boots, `archpad-clock-restore` explicitly loads the
RTC driver and adds that offset back without waiting on a static device unit.
The hourly timer updates the file only when its value changes by more than two
seconds. `systemd-timesyncd` remains responsible for network correction.

This is also the fallback for firmware that cannot persist Qualcomm's
`RTCInfo` UEFI variable. A future kernel can use the upstream
`qcom,uefi-rtc-info` device-tree mechanism after persistence is verified; this
package is intentionally safe with either arrangement because it never calls
`hwclock --systohc` and never writes PMIC registers or EFI variables.
