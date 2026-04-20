<?php

declare(strict_types=1);

namespace App\Application\Service;

// BUG: No error handling for payment gateway failures
class PaymentProcessor
{
    public function __construct(
        private readonly PaymentGateway $gateway,
        private readonly OrderRepository $orderRepository,
    ) {}

    public function processPayment(string $orderId, float $amount): void
    {
        $order = $this->orderRepository->find($orderId);

        // BUG: No null check on $order
        // BUG: No try/catch around gateway call
        $this->gateway->charge($order->getCustomerId(), $amount);

        $order->markAsPaid();
        $this->orderRepository->save($order);
    }
}
