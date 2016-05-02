<?php

class SwitcherView extends BaseView {

	public function render() {

		if (is_string($this->model->result))

			switch ($this->model->result) {
				case 'ON': $classes = 'fa fa-fire status on';
					break;
				case 'OFF': $classes = 'fa fa-fire status off';
					break;
				default: $classes = 'fa fa-exclamation-circle status undefined';
			}

		else if (is_bool($this->model->result))
			$classes = $this->model->result ? 'success' : 'danger';
		else
			$classes = 'fa fa-exclamation-triangle status undefined';

		$result = (object)[ 'result' => $this->model->result, 'classes' => $classes ];
		return json_encode($result, JSON_NUMERIC_CHECK);
	}
}