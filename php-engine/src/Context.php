<?php
declare(strict_types=1);

namespace Unleash\Yggdrasil;

use stdClass;

class Context
{
    public function __construct(
        public ?string   $userId,
        public ?string   $sessionId,
        public ?string   $remoteAddress,
        public ?string   $environment,
        public ?string   $appName,
        public ?string   $currentTime,
        public ?stdClass $properties
    )
    {
    }
}
