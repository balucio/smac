<?php

class ReportModel {

	const
		TEMPERATURA = 'temperatura',
		UMIDITA = 'umidita'
	;

	private static
		$STATUS_OK = 0b111,
		$PHYQT = 0b001,
		$START_DATE = 0b010,
		$END_DATE = 0b100
	;


	private
		$physicalQt = null,
		$start_date = null,
		$end_date = null,
		$point_number = 100,

		$status = 0
	;

	public function __construct() { }

	public function setPhysicalType($type) {

		$this->physicalQt = $type;
		$this->status |= self::$PHYQT;
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

	public function getData() {

		if ($this->status !== self::$STATUS_OK)
			return null;

		$query = "SELECT id_sensore sensore, nome_sensore nome,"
					  ." EXTRACT(epoch FROM data_ora) * 1000 data_ora,"
				      ." ({$this->physicalQt})::numeric(5,2) $this->physicalQt"
				 ." FROM report_sensori(?::timestamp, ?::timestamp, ?)";
		$stmt = Db::get()->prepare($query);
		d($query, $this->start_date, $this->end_date, $this->point_number);
		$stmt->bindParam(1, $this->start_date, PDO::PARAM_STR);
		$stmt->bindParam(2, $this->end_date, PDO::PARAM_STR);
		$stmt->bindParam(3, $this->point_number, PDO::PARAM_INT);
		$stmt->execute();
		return $stmt->fetchAll(PDO::FETCH_NUM);
	}
}
