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

	public function get($includeAvg = true) {

		if ($includeAvg)
			return $this->list;


		$list = $this->list;

		unset($list[self::ID_AVG]);

		return $list;
	}

	public function enumerate($status = self::ALL, $selected = 0) {

		$selected != $this->selected
			&& $this->selected = $selected;

		$status != $this->status
			&& $this->status = $status;

		$this->list = [];

		foreach (
			Db::get()->getResultSet(
				"SELECT * FROM elenco_sensori(:status)",
				[':status' => $status ]
		) as $v ) {

			$k = $v['id'];
			$this->list[$k] = $v;

			$this->list[$k]['selected'] = ( $selected == $k ) ? 'selected' : '';
		}
	}
}