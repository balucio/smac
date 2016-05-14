<?php

class SensorStatsView extends BaseView {

	public function render() {

        $dec = new Decorator();
        $updated = $dec->decorateDateTime('now');

		return json_encode(
            (object)[
                'points' => $this->model->getData(),
                'updated' => $updated],
            JSON_NUMERIC_CHECK
        );
	}
}