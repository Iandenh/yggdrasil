<?php
declare(strict_types=1);

namespace Unleash\Yggdrasil;

use FFI;
use FFI\CData;
use stdClass;

class UnleashEngine
{
    private FFI $ffi;
    private CData $state;

    public function __construct()
    {
        $ffiDef = file_get_contents(__DIR__ . "/../../yggdrasilffi/unleash_engine.h");
        $ffiLibPath = getenv("YGGDRASIL_LIB_PATH");
        $ffiLib = $ffiLibPath . "/libyggdrasilffi.so";
        $this->ffi = FFI::cdef($ffiDef, $ffiLib);
        $this->state = $this->ffi->new_engine();
    }

    public function __destruct()
    {
        $this->ffi->free_engine($this->state);
    }

    public function takeState(string $json): string
    {
        return $this->ffi->take_state($this->state, $json);
    }

    public function getVariant(string $toggle_name, Context $context): ?stdClass
    {
        $contextJson = json_encode($context);
        $variantJson = $this->ffi->check_variant($this->state, $toggle_name, $contextJson);

        if ($variantJson === null) {
            return null;
        }

        $variant = json_decode($variantJson);

        return $variant->value;
    }

    public function isEnabled(string $toggle_name, Context $context): bool
    {
        $contextJson = json_encode($context);
        $checkEnabledJson = $this->ffi->check_enabled($this->state, $toggle_name, $contextJson);

        $checkEnabled = json_decode($checkEnabledJson);

        return $checkEnabled->value === true;
    }
}
