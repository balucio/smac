   <?php

class BaseController {

	protected
		$model = null
	;

	private
		$default = null
	;

	public function __construct($model, $init = true) {

		$this->model = $model;

		if ($init)
			$this->initFromRequest();
	}

	public function getDefaultAction() { return $this->default; }

	protected function initFromRequest() { }

	protected function setDefaultAction($action) {
		$this->default = $action;
	}
}