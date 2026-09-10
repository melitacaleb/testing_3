<?php
/**
 * includes/db.php
 *
 * Creates a single PDO (pgsql) connection for Neon/Postgres and exposes it
 * as $conn, with a small compatibility layer so the rest of the codebase
 * (originally written against mysqli) keeps working with minimal changes:
 *
 *   - $stmt->fetch_assoc()              -> works (CompatStatement)
 *   - $stmt->fetch_all(MYSQLI_ASSOC)    -> works (arg ignored, always assoc)
 *   - $stmt->num_rows                   -> works (uses rowCount(); see note)
 *   - $conn->query($sql)                -> returns CompatStatement
 *   - $conn->prepare($sql)              -> returns CompatStatement
 *   - $conn->insert_id                  -> NOT auto-populated like mysqli.
 *                                          Use $conn->lastInsertId('table_id_seq')
 *                                          or, preferably, INSERT ... RETURNING id.
 *
 * NOTE on num_rows: PDO's rowCount() is only reliably accurate for SELECT
 * statements on some drivers. The native pgsql driver generally returns the
 * correct count for simple SELECTs, which is all this app uses, but it is
 * not part of the PDO spec/guarantee. If you hit a spot where num_rows looks
 * wrong, replace `->num_rows > 0` with `count($stmt->fetch_all()) > 0`.
 *
 * MYSQLI_ASSOC is defined below as a harmless int constant purely so old
 * calls like fetch_all(MYSQLI_ASSOC) don't fatal with "constant not defined".
 */

if (!defined('MYSQLI_ASSOC')) {
    define('MYSQLI_ASSOC', 1);
}

// Belt-and-suspenders: this file loads before config.php's display_errors
// setting takes effect, so any deprecation notice thrown while building the
// connection would otherwise print directly into the page and break later
// header()/session_start() calls. Real fix is matching PDO's native method
// signatures (done below); this just prevents any future regression from
// doing the same thing.
error_reporting(E_ALL & ~E_DEPRECATED & ~E_NOTICE);

class CompatStatement extends PDOStatement
{
    public function fetch_assoc()
    {
        $row = $this->fetch(PDO::FETCH_ASSOC);
        return $row === false ? null : $row;
    }

    public function fetch_all($mode = null)
    {
        return $this->fetchAll(PDO::FETCH_ASSOC);
    }

    public function get_result()
    {
        // mysqli_stmt::get_result() compatibility - PDOStatement already
        // behaves like the "result" in this codebase, so just return self.
        return $this;
    }

    public function bind_param($types, &...$params)
    {
        // mysqli-style bind_param("ssi", $a, $b, $c) -> PDO positional execute().
        // We just stash the values; execute() will be called separately by
        // the caller exactly like mysqli usage, so we store them on the
        // instance and override execute() to use them if no args given.
        $this->__compat_bound = $params;
        return true;
    }

    #[\ReturnTypeWillChange]
    public function execute(?array $params = null): bool
    {
        if ($params === null && isset($this->__compat_bound)) {
            $params = $this->__compat_bound;
        }
        return parent::execute($params);
    }

    public $__compat_bound = null;

    public function __get($name)
    {
        if ($name === 'num_rows') {
            return $this->rowCount();
        }
        if ($name === 'error') {
            $info = $this->errorInfo();
            return $info[2] ?? '';
        }
        return null;
    }
}

class CompatPDO extends PDO
{
    /** @var string last error message, mysqli-style $conn->error */
    public $error = '';

    #[\ReturnTypeWillChange]
    public function query(string $statement, ?int $fetchMode = null, mixed ...$fetchModeArgs)
    {
        try {
            if ($fetchMode !== null) {
                return parent::query($statement, $fetchMode, ...$fetchModeArgs);
            }
            return parent::query($statement);
        } catch (PDOException $e) {
            $this->error = $e->getMessage();
            return false;
        }
    }

    public function real_escape_string($value)
    {
        // No-op-ish compatibility shim. Prefer prepared statements for any
        // new code; this only exists so old call sites don't fatal. It
        // strips quotes defensively but should NOT be relied on for safety.
        return str_replace(["'", '"', "\\"], '', (string)$value);
    }

    #[\ReturnTypeWillChange]
    public function begin_transaction(): bool
    {
        return $this->beginTransaction();
    }

    #[\ReturnTypeWillChange]
    public function rollback(): bool
    {
        return $this->rollBack();
    }

    /**
     * Run an INSERT that ends with RETURNING id and return that id,
     * the Postgres-friendly replacement for mysqli's auto-populated
     * $conn->insert_id.
     */
    public function insertReturningId($sql, $params = [])
    {
        if (stripos($sql, 'returning') === false) {
            $sql .= ' RETURNING id';
        }
        $stmt = $this->prepare($sql);
        $stmt->execute($params);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return $row['id'] ?? null;
    }
}

/**
 * Build the PDO DSN from either a single DATABASE_URL (Neon gives you this,
 * e.g. postgres://user:pass@host/dbname?sslmode=require) or discrete
 * PG* env vars. Render lets you set either as Environment Variables on the
 * service.
 */
function build_pdo_connection(): CompatPDO
{
    $databaseUrl = getenv('DATABASE_URL');

    if ($databaseUrl) {
        $parts = parse_url($databaseUrl);
        $host = $parts['host'] ?? 'localhost';
        $port = $parts['port'] ?? 5432;
        $dbname = ltrim($parts['path'] ?? '', '/');
        $user = $parts['user'] ?? '';
        $pass = $parts['pass'] ?? '';
        // Neon requires SSL.
        $dsn = "pgsql:host={$host};port={$port};dbname={$dbname};sslmode=require";
    } else {
        $host = getenv('PGHOST') ?: 'localhost';
        $port = getenv('PGPORT') ?: '5432';
        $dbname = getenv('PGDATABASE') ?: 'motorist_system';
        $user = getenv('PGUSER') ?: 'postgres';
        $pass = getenv('PGPASSWORD') ?: '';
        $sslmode = getenv('PGSSLMODE') ?: 'prefer';
        $dsn = "pgsql:host={$host};port={$port};dbname={$dbname};sslmode={$sslmode}";
    }

    $conn = new CompatPDO($dsn, $user, $pass, [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION,
        PDO::ATTR_STATEMENT_CLASS => [CompatStatement::class],
        PDO::ATTR_EMULATE_PREPARES => true,
    ]);

    return $conn;
}

try {
    $conn = build_pdo_connection();
} catch (PDOException $e) {
    die("Connection failed: " . $e->getMessage());
}

// Site configuration (shared across admin + users areas)
if (!defined('SITE_NAME')) {
    define('SITE_NAME', getenv('SITE_NAME') ?: 'Motorcycle Traffic Control System');
}
if (!defined('SITE_URL')) {
    define('SITE_URL', getenv('SITE_URL') ?: '/');
}
if (!defined('SITE_VERSION')) {
    define('SITE_VERSION', '2.0.0');
}
