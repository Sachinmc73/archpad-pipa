# hexagonrpc

Native Arch packaging for upstream HexagonRPC `v0.4.0` at commit
`23a69640bf10dc498226c602c5b5db11d8cb3d8e`.

The package is device-independent. It supplies the FastRPC library,
`hexagonrpcd`, CHRE daemon and upstream tools. Device-specific daemon arguments,
firmware roots and service ordering belong to the appropriate ArchPad device
package.

Package release 2 carries one narrow, upstream-shaped HexagonFS patch. It maps
the read-only `sns_reg_version` marker requested by Qualcomm sensor firmware;
upstream `v0.4.0` maps the registry itself but not this sibling marker.
