<?php

declare(strict_types=1);

namespace App\Infrastructure\Persistence;

use App\Domain\User\User;

class UserRepository
{
    public function findById(string $id): ?User
    {
        // TODO: implement
    }

    public function save(User $user): void
    {
        // TODO: implement
    }

    public function findAll(): array
    {
        // TODO: implement
    }

    public function delete(string $id): void
    {
        // TODO: implement
    }
}
