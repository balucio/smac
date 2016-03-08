<?php

class ProgramScheduleView extends BaseView {

	public function render() {

		$tpl = Template::get()->loadTemplate('programschedulesettings.tpl');

//		return '<pre>' . json_encode( $rv, JSON_PRETTY_PRINT) . '</pre>';
		return json_encode(
			(object)[ 'shedule' => $tpl->render([ 'programma' => $this->model ]) ],
			JSON_HEX_QUOT | JSON_HEX_TAG
		);
	}
}