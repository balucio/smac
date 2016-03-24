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
			: $this->list->get($type == 'list')
		;
	}

	public function setSidForData($sid = 0, $show = SensorListModel::ALL) {

		// Selezionato per default sensore media "Media" 0
		$this->data->collectData($sid);
		$this->list->enumerate($show, $sid);
	}

	public function setSid($sid = 0, $show = SensorListModel::ENABLED) {

		// Selezionato per default sensore media "Media" 0
		$this->data->collectEnviromentalData($sid);
		$this->list->enumerate($show, $sid);
	}
}