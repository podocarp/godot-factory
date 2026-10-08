class_name SdkVersion
extends RefCounted
# Single source of truth for the SDK version; keep in sync with sdk/VERSION
# (checked by scripts/check_vendor.sh, which reads sdk/VERSION directly).
# Vendored copies (games/<name>/vendor/sdk/VENDOR.md) pin this value; any
# byte drift between a vendored file and its sdk/ source is a DRIFT error.

const VERSION := "0.1.0"
