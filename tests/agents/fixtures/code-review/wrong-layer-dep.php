<?php

declare(strict_types=1);

namespace App\Domain\Model;

// BUG: Domain layer importing infrastructure class
use App\Infrastructure\Persistence\Doctrine\DoctrineUserRepository;
use App\Infrastructure\Http\GuzzleHttpClient;

class UserService
{
    public function __construct(
        // BUG: Domain depends on infrastructure implementation
        private readonly DoctrineUserRepository $userRepository,
        private readonly GuzzleHttpClient $httpClient,
    ) {}

    public function findActiveUsers(): array
    {
        return $this->userRepository->findByStatus('active');
    }

    public function notifyUser(string $userId, string $message): void
    {
        $user = $this->userRepository->find($userId);
        // BUG: Using infrastructure HTTP client directly in domain
        $this->httpClient->post('/notifications', [
            'userId' => $userId,
            'message' => $message,
        ]);
    }
}
