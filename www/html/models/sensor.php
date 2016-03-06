<?php

class SensorModel {

	private
		$data = null,
		$list = null
	;

	public function __construct() {

		$this->data = new SensorDataModel();
		$this->list = new SensorListModel();
	}

	public function get($type) {
		return $type == 'data'
			? $this->data->get()
			: $this->list->get()
		;
	}

	public function setSid($sid = 0, $show = SensorListModel::ENABLED) {

		// Selezionato per default sensore media "Media" 0
		$this->data->setSid($sid);
		$this->list->enumerate($show, $sid);
	}
}