   <?php

class GenericController {

	protected

		$action = null,
		$model = null
	;

	public function __construct($model, $init = true) {

		$this->model = $model;

		if ($init)
			$this->initFromRequest();
	}

	protected function initFromRequest() {

		$this->model->initData();
	}
}