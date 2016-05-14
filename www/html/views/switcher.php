<?php

class SwitcherView extends BaseView {

	public function render() {

		$stato = isset($this->model->result['stato'])
			? $this->model->result['stato']
			: null;
		$data_ora = isset($this->model->result['data_ora'])
			? $this->model->result['data_ora']
			: 'now';

		$dec = new Decorator();
        $updated = $dec->decorateDateTime($data_ora);

		switch ($stato) {
			case True:
				$classes = 'fa fa-fire status on';
				$title = 'title-status-on';
				break;
			case False:
				$classes = 'fa fa-fire status off';
				$title = 'title-status-off';
				break;
			default:
				$classes = 'fa fa-exclamation-circle status undefined';
				$title = 'title-status-unknow';
		}

		$result = (object)[
			'result' => $stato,
			'classes' => $classes,
			'title' => $title,
			'updated' => $updated
		];
		return json_encode($result, JSON_NUMERIC_CHECK);
	}
}