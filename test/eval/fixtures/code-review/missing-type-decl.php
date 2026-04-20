<?php

// BUG: Missing declare(strict_types=1)

namespace App\Application\Command;

class CreateUserHandler
{
    // BUG: Missing property type declaration
    private $userRepository;
    private $eventDispatcher;

    // BUG: Missing parameter types
    public function __construct($userRepository, $eventDispatcher)
    {
        $this->userRepository = $userRepository;
        $this->eventDispatcher = $eventDispatcher;
    }

    // BUG: Missing return type, missing parameter type
    public function handle($command)
    {
        $user = $this->userRepository->create(
            $command->email,
            $command->name
        );

        // BUG: No type safety on the event
        $this->eventDispatcher->dispatch('user.created', $user);

        return $user;
    }
}
