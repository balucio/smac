<?php

class ProgramScheduleView extends BaseView {

	public function render() {

		$tpl = Template::get()->loadTemplate('programschedulesettings.tpl');

//		return '<pre>' . json_encode( $rv, JSON_PRETTY_PRINT) . '</pre>';
		return json_encode(
			(object)[ 'schedule' => $tpl->render([
				'programma' => $this->model,
				'temperature' => $this->model->temperature,
			]) ],
			JSON_HEX_QUOT | JSON_HEX_TAG
		);
	}
}