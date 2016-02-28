<?php

class SensorListModel {

	const ENABLED = true;
	const DISABLED = false;
	const ALL = null;
	const ID_AVG = 0;

	private

		$list = null,

		$selected = null,
		$status = null
	;

	public function __construct($status = self::ALL, $selected = 0) {

		$this->selected = $selected;
		$this->status = $status;
	}

	public function getList($includeAvg = true) {

		return $includeAvg 
			? $this->list
			: (isset($this->list[self::ID_AVG])
				? array_slice($this->list, 1, null, true)
				: $this->list
		);
	}

	public function sensorList($status = self::ALL, $selected = 0) {

		$selected != $this->selected
			&& $this->selected = $selected;

		$status != $this->status
			&& $this->status = $status;

		$this->list = [];

		foreach ($this->enumerate($status) as $v) {

			$k = $v['id_sensore'];
			$this->list[$k] = $v;

			$this->list[$k]['selected'] = ( $selected == $k ) ? 'selected' : '';
		}
	}

	private function enumerate($status) {

		$query = "SELECT * FROM elenco_sensori(:status)";

		return Db::get()->getResultSet(
			$query, [':status' => $status ]
		);
	}
}