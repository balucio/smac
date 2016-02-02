<?php

/** manage incoming request */

class FrontController {

	protected

		$route = null,

		$controller = null,
		$view = null,

		$action = null,
		$params = array()
	;

	public function __construct($router, $route, $action, $params) {

		$this->router = $router;
		$this->setRoute($route)->setAction($action)->setParams($params);
	}

	public function setRoute($route) {

		$route = $this->router->$route ?: $this->router->{Router::DEFAULT_ROUTE};

		$modelName = $route->model;
		$model = new $modelName();

		$controllerName = $route->controller;
		$this->controller = new $controllerName($model);
		$viewName = $route->view;
		$this->view = new $viewName($this->controller, $model);

		return $this;
	}

	public function setAction($action) {

		if (method_exists($this->controller, $action))
			$this->action = $action;
		else
			error_log("The controller action '$action' has been not defined.");

		return $this;
	}

	public function setParams($params) {
		$this->params = $params;
		return $this;
	}

	public function run() {

		if (!empty($this->action))
			$this->controller->{$this->action}($this->params);

		if (Request::IsAjax())
			header("Content-type: application/json");
		echo $this->view->render();
	}

}