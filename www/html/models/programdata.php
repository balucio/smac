<?php

class ProgramDataModel {

	const
		DAY_ALL=0,
		DAY_NOW=null
	;

	private
		$pid = null,
		$programma = null,
		$status = null
	;

	public function __construct() { }

 	public function __isset($v) { return $this->programma->__isset($v); }
	public function __get($v) { return $this->programma->$v; }

	public function get() { return $this->programma; }

	public function getPid() { return $this->pid; }

	public function getStatus() { return $this->status; }

	public function setPid($pid = null, $pday = null) {

		$this->pid = $pid;

		$this->programma = new Programma(
			$this->getData($pid),
			$this->getDetails($pid, $pday)
		);
	}

	public function exists($pid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_programma(:pid::smallint)",
			[':pid' => $pid ]
		);
	}

	public function getIdByName($nome) {

		$query ="SELECT id_programma FROM programmi WHERE nome_programma = :nome";
		return Db::get()->getNthColumnOfRow( $query, [ ':nome' => $nome] );
	}

	public function updateProgram( $pid, $nome, $descr, $temps, $sid ) {

		$pid = ( empty($pid) || $pid < 0 ) ? null : $pid;

		$data = [
			':pid' => $pid,
			':nome' => $nome,
			':descrizione' => $descr,
			':temps' => '{' . implode(',', $temps) . '}',
			':sensore' => $sid
		];

		$epid = $this->getIdByName($nome);

		if ( !empty($pid) && !$this->exists($pid) ) {

				$this->status = Db::STATUS_KEY_NOT_EXIST;
				return;

		} else if (
			( empty($pid) && !empty($epid) )
			|| ( !empty($pid) && $epid != $pid )
		) {
				$this->status = Db::STATUS_DUPLICATE;
				return;
		}

		$sth = null;
		$query = "SELECT * FROM aggiorna_crea_programma(:nome, :descrizione, :temps, :sensore::smallint, :pid)";

		try {

			$sth = Db::get()->prepare( $query );
			$sth->execute( $data );
			$this->pid = $sth->fetchColumn(0);
			$this->status = Db::STATUS_OK;

		} catch (Exception $e) {

			$msg = $sth ? $sth->errorInfo() : Db::get()->errorInfo();
			error_log( "SQLSTATE {$msg[0]} - {$msg[1]} : {$msg[2]}");

			$this->pid = null;
			$this->status = Db::STATUS_ERR;
		}
	}

	public function setDefault($pid) {

		Db::get()->saveSetting(Db::CURR_PROGRAM, $pid);
		$this->pid = $pid;
	}

	public function getDefault() {
		return $this->pid = Db::get()->readSetting(Db::CURR_PROGRAM, '-1');
	}

	private function getData($pid) {

		$query = "SELECT *, array_to_json(temperature_rif) as json_t_rif FROM dati_programma(:id)";
		return Db::get()->getFirstRow($query, [':id' => $pid]);
	}

	private function getDetails($pid, $day = self::DAY_NOW) {

		return Db::get()->getResultSet(
			"SELECT * FROM programmazioni(:id, :day)",
			[':id' => $pid, ':day' => $day ]
		);
	}
}