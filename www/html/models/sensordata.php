<?php

class SensorDataModel {

	const
		TEMPERATURA = 'temperatura',
		UMIDITA = 'umidita'
	;

	private
		$dbh = null,
		$data = null,
		$measureType = null,
		$startDate = null,
		$endDate = null
	;

	public function __construct($sensorId = null) {

		if ($sensorId)
			$this->setSensorId($sensorId);
	}

	public function __isset($key) {

		return array_key_exists($key, $this->data);
	}

	public function __get($data) {

		return $this->data[$data];
	}

	public function setSensorId($sid) {

		if (!$this->sensorExists($sid))
			return false;

		$this->data = Db::get()->getFirstRow(
			"SELECT * FROM dati_sensore(:sid)",
			[':sid' => $sid ]
		);

		return true;
	}

	public function sensorExists($sid) {

		return Db::get()->getNthColumnOfRow(
			"SELECT esiste_sensore(:sid::smallint)",
			[':sid' => $sid ]
		);
	}


	public function setMeasureType($type) {
		$this->measureType = $type;
		return $this;
	}

	public function setStartDate($sd) {
		$this->startDate = $sd;
		return $this;
	}

	public function setEndDate($ed) {
		$this->endDate = $ed;
		return $this;
	}

	public function getStats() {

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