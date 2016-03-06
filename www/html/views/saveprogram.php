<?php

class SaveProgramView extends BaseView {

	public function render() {

		$pid = $this->model->getPid();
		return json_encode( ['program'  => $pid ] );
	}
}