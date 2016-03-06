<?php

class SensorStatsView extends BaseView {

	public function render() {

		return json_encode($this->model->getData(), JSON_NUMERIC_CHECK);
	}
}