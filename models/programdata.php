<?php

class ProgramDataModel {

	private
		$dbh = null,
		$programma = null
	;

	public function __construct() {

		$this->dbh = Db::get();
	}

	public function programdata() {

		return $this->programma;
	}

	public function setProgramId($programId, $day) {

		$this->programma = new Programma(
			$this->getProgramData($programId),
			$this->getProgramDetails($programId, $day)
		);
	}

	private function getProgramData($programId) {

		$query = "SELECT *, array_to_json(temperature_rif) as json_t_rif FROM dati_programma(:id)";

		return $this->dbh->getFirstRow($query, [':id' => $programId]);

	}

	private function getProgramDetails($programId, $day = null) {

		return $this->dbh->getResultSet(
			"SELECT * FROM programmazioni(:id, :day)",
			[':id' => $programId, ':day' => $day ]
		);
	}
}