<?php

class SensorDriverListView extends BaseView {

	public function render() {

		return json_encode(['driverlist' => array_values($this->model->get()) ]);

	}
}