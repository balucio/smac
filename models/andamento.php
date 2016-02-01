<?php

class AndamentoModel {

	const
		TEMPERATURA = 'temperatura',
		UMIDITA = 'umidita'
	;

	private
		$dbh = null,
		$physicalType = null,
		$sensorId = null,
		$start_date = null,
		$end_date = null
	;

	public function __construct() {

		$this->dbh = Db::get();

	}

	public function setPhysicalType($type) {
		$this->physicalType = $type;
		return $this;
	}

	public function setSensorId($sid) {
		$this->sensorId = $sid;
		return $this;
	}

	public function setStartDate($sd) {
		$this->start_date = $sd;
		return $this;
	}

	public function setEndDate($ed) {
		$this->end_date = $ed;
		return $this;
	}

	public function getData() {

		$query = "SELECT EXTRACT(epoch FROM data_ora) * 1000,"
			. "({$this->physicalType})::numeric(5,2) FROM "
			. "report_misurazioni(?::smallint, ?::timestamp, ?::timestamp)";

		$stmt = $this->dbh->prepare($query);

		$stmt->bindParam(1, $this->sensorId, PDO::PARAM_INT);
		$stmt->bindParam(2, $this->start_date, PDO::PARAM_STR);
		$stmt->bindParam(3, $this->end_date, PDO::PARAM_STR);

		$stmt->execute();
		return $stmt->fetchAll(PDO::FETCH_NUM);
	}


}