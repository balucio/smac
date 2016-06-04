<?php

class SensorStatsModel {

	const
		TEMPERATURA = 'temperatura',
		UMIDITA = 'umidita'
	;

	private static
		$MIS_REPORT_OK = 0b1111,
		$SENSOR_REPORT_OK = 0b1101,
		$PHYQT = 0b0001,
		$SID = 0b0010,
		$START_DATE = 0b0100,
		$END_DATE = 0b1000
	;


	private
		$physicalQt = null,
		$sensorId = null,
		$start_date = null,
		$end_date = null,
		$point_number = 100,

		$getData = null,

		$status = 0
	;

	public function __construct() { }

	public function setPhysicalType($type) {

		$this->physicalQt = $type;
		$this->status |= self::$PHYQT;
		return $this;
	}

	public function setSensorId($sid) {

		$this->sensorId = $sid;
		$this->status |= self::$SID;
		return $this;
	}

	public function setStartDate($sd) {

		$this->start_date = $sd;
		$this->status |= self::$START_DATE;
		return $this;
	}

	public function setEndDate($ed) {

		$this->end_date = $ed;
		$this->status |= self::$END_DATE;
		return $this;
	}

	public function setNumberOfPoint($sc) {

		$this->point_number = $sc;
		return $this;
	}

	public function setFunction($fn_name) {
		$this->getData = $fn_name;
	}

	public function getData() {

		if (method_exists($this, $this->getData))
			return $this->{$this->getData}();

		return [];
	}

	public function reportSensori() {

		if ($this->status !== self::$SENSOR_REPORT_OK)
			return null;

		$query = "SELECT id_sensore sensore, nome_sensore nome,"
					  ." EXTRACT(epoch FROM data_ora) * 1000 data_ora,"
				      ." ({$this->physicalQt})::numeric(5,2) $this->physicalQt"
				 ." FROM report_sensori(?::timestamp, ?::timestamp, ?)";
		$stmt = Db::get()->prepare($query);

		$stmt->bindParam(1, $this->start_date, PDO::PARAM_STR);
		$stmt->bindParam(2, $this->end_date, PDO::PARAM_STR);
		$stmt->bindParam(3, $this->point_number, PDO::PARAM_INT);

		$stmt->execute();
		return $stmt->fetchAll(PDO::FETCH_NUM);
	}

	public function reportMisurazioni() {

		if ($this->status !== self::$MIS_REPORT_OK)
			return null;

		$query = "SELECT EXTRACT(epoch FROM data_ora) * 1000,"
				. "({$this->physicalQt})::numeric(5,2) FROM "
				. "report_misurazioni(?::smallint, ?::timestamp, ?::timestamp)";
		// d($query, $this->sensorId, $this->start_date, $this->end_date);

		$stmt = Db::get()->prepare($query);

		$stmt->bindParam(1, $this->sensorId, PDO::PARAM_INT);
		$stmt->bindParam(2, $this->start_date, PDO::PARAM_STR);
		$stmt->bindParam(3, $this->end_date, PDO::PARAM_STR);

		$stmt->execute();
		return $stmt->fetchAll(PDO::FETCH_NUM);
	}


}