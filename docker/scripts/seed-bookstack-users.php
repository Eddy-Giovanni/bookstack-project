<?php

declare(strict_types=1);

/**
 * Crée les utilisateurs par défaut documentés dans le README (idempotent).
 * Exécuté au démarrage du conteneur lorsque BOOKSTACK_SEED_USERS=true.
 */

$bookstackRoot = '/app/www';

if (!is_dir($bookstackRoot)) {
    fwrite(STDERR, "[seed-users] Répertoire BookStack introuvable: {$bookstackRoot}\n");
    exit(0);
}

if (filter_var(getenv('BOOKSTACK_SEED_USERS') ?: 'true', FILTER_VALIDATE_BOOLEAN) === false) {
    echo "[seed-users] BOOKSTACK_SEED_USERS=false, création ignorée.\n";
    exit(0);
}

$maxAttempts = (int) (getenv('BOOKSTACK_SEED_MAX_ATTEMPTS') ?: 60);
$dbHost = getenv('DB_HOST') ?: 'database';
$dbPort = getenv('DB_PORT') ?: '3306';
$dbName = getenv('DB_DATABASE') ?: 'bookstack';
$dbUser = getenv('DB_USERNAME') ?: 'bookstack_user';
$dbPass = getenv('DB_PASSWORD') ?: '';

$connected = false;
$dsn = "mysql:host={$dbHost};port={$dbPort};dbname={$dbName};charset=utf8mb4";

for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
    try {
        new PDO($dsn, $dbUser, $dbPass, [
            PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_TIMEOUT => 5,
        ]);
        $connected = true;
        break;
    } catch (Throwable $e) {
        echo "[seed-users] En attente de la base ({$attempt}/{$maxAttempts})...\n";
        sleep(5);
    }
}

if (!$connected) {
    fwrite(STDERR, "[seed-users] Base indisponible, création des utilisateurs ignorée.\n");
    exit(0);
}

chdir($bookstackRoot);
require $bookstackRoot . '/vendor/autoload.php';
$app = require $bookstackRoot . '/bootstrap/app.php';
/** @var \Illuminate\Contracts\Console\Kernel $kernel */
$kernel = $app->make(\Illuminate\Contracts\Console\Kernel::class);
$kernel->bootstrap();

$migrationsReady = false;
for ($attempt = 1; $attempt <= $maxAttempts; $attempt++) {
    try {
        if (\Illuminate\Support\Facades\Schema::hasTable('users')) {
            $migrationsReady = true;
            break;
        }
    } catch (Throwable $e) {
        // schéma pas encore prêt
    }
    echo "[seed-users] En attente des migrations ({$attempt}/{$maxAttempts})...\n";
    sleep(5);
}

if (!$migrationsReady) {
    fwrite(STDERR, "[seed-users] Table users absente, création ignorée.\n");
    exit(0);
}

use BookStack\Users\Models\Role;
use BookStack\Users\Models\User;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Hash;

function createAdminIfMissing(string $email, string $name, string $password): void
{
    if (User::query()->where('email', $email)->exists()) {
        echo "[seed-users] Admin déjà présent: {$email}\n";
        return;
    }

    $exitCode = Artisan::call('bookstack:create-admin', [
        '--email' => $email,
        '--name' => $name,
        '--password' => $password,
        '--no-interaction' => true,
    ]);

    if ($exitCode === 0) {
        echo "[seed-users] Admin créé: {$email}\n";
        return;
    }

    fwrite(STDERR, "[seed-users] Échec création admin {$email}: " . Artisan::output() . "\n");
}

function createPublicReaderIfMissing(string $email, string $name, string $password): void
{
    if (User::query()->where('email', $email)->exists()) {
        echo "[seed-users] Lecteur déjà présent: {$email}\n";
        return;
    }

    $user = new User();
    $user->name = $name;
    $user->email = $email;
    $user->password = Hash::make($password);
    $user->email_confirmed = true;
    $user->save();

    $role = Role::query()->where('system_name', 'public')->first();
    if ($role !== null) {
        $user->roles()->attach($role->id);
    }

    echo "[seed-users] Lecteur (rôle Public) créé: {$email}\n";
}

createAdminIfMissing(
    getenv('BOOKSTACK_ADMIN_EMAIL') ?: 'admin@admin.com',
    getenv('BOOKSTACK_ADMIN_NAME') ?: 'Admin',
    getenv('BOOKSTACK_ADMIN_PASSWORD') ?: 'password'
);

createAdminIfMissing(
    getenv('BOOKSTACK_ADMIN2_EMAIL') ?: 'nguetsamiguel@gmail.com',
    getenv('BOOKSTACK_ADMIN2_NAME') ?: 'Miguel Nguetsa',
    getenv('BOOKSTACK_ADMIN2_PASSWORD') ?: 'azerty12'
);

createPublicReaderIfMissing(
    getenv('BOOKSTACK_READER_EMAIL') ?: 'lecteur@example.com',
    getenv('BOOKSTACK_READER_NAME') ?: 'Lecteur Test',
    getenv('BOOKSTACK_READER_PASSWORD') ?: 'qwerty'
);

Artisan::call('cache:clear');
echo "[seed-users] Terminé.\n";
