<?php

class SensorDataModel {

	private
		$data = null,
		$status = null
	;

	public function __construct() {

	}

	public function __get($v) {

		return $this->data[$v];
	}

	public function getStatus() { return $this->status; }

	public function get() { return $this->data; }

	public function collectData($sid) {

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM elenco_sensori() WHERE id = :sid",
			[':sid' => $sid ]
		);
	}

	public function collectEnviromentalData($sid) {

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM dati_sensore(:sid)",
			[':sid' => $sid ]
		);
	}

	public function exists($sid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_sensore(:sid::smallint, null::boolean)",
			[':sid' => $sid]
		);
	}

	public function delete($sid) {

		try {

			$count = Db::get()->getNthColumnOfRow(
				"SELECT COUNT(sensore_rif) FROM elenco_programmi() WHERE sensore_rif = :sid::smallint",
				[':sid' => $sid]
			);

			if ($count > 0) {
				$this->status = Db::STATUS_KEY_USED;
			} else {

				$sth = Db::get()->prepare("DELETE FROM sensori WHERE id_sensore = :sid::smallint");
				$sth->execute([':sid' => (int)$sid ]);
				$this->data = $sid;
				$this->status = Db::STATUS_OK;
			}

		} catch (Exception $e) {

			error_log($e->getMessage());
			$msg = $sth ? $sth->errorInfo() : Db::get()->errorInfo();
			error_log( "SQLSTATE {$msg[0]} - {$msg[1]} : {$msg[2]}");

			$this->data = null;
			$this->status = Db::STATUS_ERR;
		}
	}

	public function getIdByName($nome) {

		$query ="SELECT id_sensore FROM sensori WHERE nome_sensore = :nome";
		return Db::get()->getNthColumnOfRow( $query, [ ':nome' => $nome] );
	}

	public function updateSensor( $data ) {

		$sid = ( empty($data['sid']) || $data['sid'] < 0 ) ? null : $data['sid'];

		$esid = $this->getIdByName($data['name']);

		if ( !empty($sid) && !$this->exists($sid) ) {

				$this->status = Db::STATUS_KEY_NOT_EXIST;
				return;

		} else if ( !empty($esid) && (empty($sid) || $esid != $sid ) ) {

				$this->status = Db::STATUS_DUPLICATE;
				return;
		}

		$sth = null;
		$query = empty($sid)
			? 'INSERT INTO sensori(nome_sensore, descrizione, abilitato, incluso_in_media, id_driver, parametri)'
				. ' VALUES(:name, :description, :enabled, :inaverage, :driver, :parameters)'
				. ' RETURNING id_sensore'
			: 'UPDATE sensori SET nome_sensore = :name, descrizione = :description, abilitato = :enabled,'
				. ' incluso_in_media = :inaverage, id_driver = :driver, parametri = :parameters'
				. ' WHERE id_sensore = :sid::smallint'
		;

		try {

			$sth = Db::get()->prepare( $query );

			$sth->bindValue(':name', $data['name'], PDO::PARAM_STR);
			$sth->bindValue(':description', $data['description'], PDO::PARAM_STR);
			$sth->bindValue(':enabled', $data['enabled'], PDO::PARAM_BOOL);
			$sth->bindValue(':inaverage', $data['inaverage'], PDO::PARAM_BOOL);
			$sth->bindValue(':driver', $data['driver'], PDO::PARAM_STR);
			$sth->bindValue(':parameters', $data['parameters'], PDO::PARAM_STR);

			if (!empty($sid))
				$sth->bindValue(':sid', $sid, PDO::PARAM_INT);

			$sth->execute();
			$this->data = empty($sid)
				? $sth->fetchColumn(0)
				: $sid;

			$this->status = Db::STATUS_OK;

		} catch (Exception $e) {
			$msg = $sth ? $sth->errorInfo() : Db::get()->errorInfo();
			error_log("Exception Message: {$e->getMessage()}");
			error_log( "SQLSTATE {$msg[0]} - {$msg[1]} : {$msg[2]}");

			$this->data = null;
			$this->status = Db::STATUS_ERR;
		}
	}

}