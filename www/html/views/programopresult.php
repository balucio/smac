<?php

class ProgramOpResultView extends BaseView {

	public function render() {

		$status = $this->model->getStatus();

		switch ($status) {
			case Db::STATUS_OK : $msgid = ''; break;
			case Db::STATUS_DUPLICATE : $msgid = 'message-err-duplicate'; break;
			case Db::STATUS_ERR : $msgid = 'message-err-db'; break;
			default: $msgid = 'message-err-data';
		}

		return json_encode((object)[
			'status' => $status === Db::STATUS_OK,
			'code' => $status,
			'pid' => $this->model->getPid(),
			'msgid' => $msgid
		]);
	}
}