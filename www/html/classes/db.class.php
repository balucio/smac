<?php

class Db {

	const CURR_PROGRAM = 'programma_attuale';
	const CURR_ANTIFREEZE_SENSOR = 'programma_anticongelamento_sensore';
	const CURR_MANUAL_SENSOR ='programma_manuale_sensore';
	const CURR_ANTIFREEZE_TEMP = 'temperatura_anticongelamento';
	const CURR_MANUAL_TEMP = 'temperatura_manuale';

	const STATUS_OK = 0;
	const STATUS_DUPLICATE = 1;
	const STATUS_KEY_NOT_EXIST = 2;
	const STATUS_KEY_USED = 4;
	const STATUS_ERR = -1;

	private static $instance = null;

	private static $dsn_tpl='%s:host=%s;port=%s;dbname=%s;';

	private function __construct() {}

	private function __clone() {}

	private function __wakeup() {}

	static public function get() {

		if (self::$instance == null) {

			LoadConfig('DbConfig');
			try {
				self::$instance = new DataBase(
					sprintf(
						self::$dsn_tpl,
						DbConfig::driver,
						DbConfig::host,
						DbConfig::port,
						DbConfig::schema
					),
					DbConfig::user,
					DbConfig::pass
				);
			} catch (Exception $e) {

				error_log("Error accessing database : " . $e->getMessage());

				$msg ="<h5>Si è verificato un'errore di accesso al database</h5>"
					. "<pre>" . $e->getMessage() . "</pre>"
					. "<p>Ci scusiamo per il disagio</p>"
				;
				Template::Error_505($msg);
			}
		}

	  return self::$instance;
	}

	static function TimestampWt( $epoch = null ) {
		return gmdate('Y-m-d H:i:s', ( $epoch ?: time() ));
	}

	static function Timestamp( $epoch = null ) {
		return date('Y-m-d H:i:s', ( $epoch ?: time() ));
	}

	static function UTC( $timestamp = null ) {
		return (int)( ( $timestamp ?: time() ) - date('Z') );
	}
}


class DataBase extends PDO {

	public function __construct($dsn, $user, $pass) {

		parent::__construct($dsn, $user, $pass);

		try {
			$this->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);

		} catch (PDOException $e) {

			die($e->getMessage());
		}
	}

	public function readSetting($name, $default = null) {

		$set = $this->getFirstRow(
			"SELECT get_setting(:name::varchar, :default::text)",
			[':name' => (string)$name, ':default' => (string)$default ]
		);

		return $set['get_setting'];
	}

	public function saveSetting($name, $value) {

		$this->getFirstRow(
			"SELECT set_setting(:name::varchar, :value::text)",
			[':name' => (string)$name, ':value' => (string)$value ]
		);
	}

	public function getResultSet($query, $bind = null, $mode = PDO::FETCH_ASSOC) {

		$stmt = $this->getStmt($query, $bind);

		return $stmt->fetchAll($mode);

	}

	public function getFirstRow($query, $bind = null, $mode = PDO::FETCH_ASSOC) {

		$stmt = $this->getStmt($query, $bind);
		$stmt->execute($bind);

		$data = $stmt->fetch($mode);

		$stmt->closeCursor();

		return $data;

	}

	public function getNthColumnOfRow($query, $bind = null, $col = 0) {

		$data = $this->getFirstRow($query, $bind, PDO::FETCH_NUM);

		return isset($data[$col]) ? $data[$col] : null;
	}

	private function getStmt($query, $bind = null) {

		$stmt = $this->prepare($query);
		$stmt->execute($bind);

		return $stmt;

	}
}