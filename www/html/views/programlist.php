<?php

class ProgramListView extends BaseView {

	public function render() {

		$tpl = Template::get()->loadTemplate('programdetailssettings.tpl');

		return json_encode(
			(object)[ 'programlist' => $tpl->render([
				'programmi' => $this->model->get()
			]) ],
			JSON_HEX_QUOT | JSON_HEX_TAG
		);
	}
}