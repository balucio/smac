<?php

class SensorDetailsView extends BaseView {

	public function render() {

		return json_encode($this->model->get(), JSON_NUMERIC_CHECK);
	}
}