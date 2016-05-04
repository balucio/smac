<?php

class SwitcherView extends BaseView {

	public function render() {

		if (is_string($this->model->result))

			switch ($this->model->result) {
				case 'ON':
					$classes = 'fa fa-fire status on';
					$title = 'title-status-on';
					break;
				case 'OFF':
					$classes = 'fa fa-fire status off';
					$title = 'title-status-off';
					break;
				default:
					$classes = 'fa fa-exclamation-circle status undefined';
					$title = 'title-status-unknow';
			}

		else if (is_bool($this->model->result)) {
			$classes = $this->model->result ? 'success' : 'danger';
			$title = ''; // TODO
		}
		else {
			$classes = 'fa fa-exclamation-triangle status undefined';
			$title = 'title-op-error'; // TODO
		}

		$result = (object)[
			'result' => $this->model->result,
			'classes' => $classes,
			'title' => $title
		];
		return json_encode($result, JSON_NUMERIC_CHECK);
	}
}