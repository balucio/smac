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

	public function __construct($route, $action, $params) {

		// Routes are two levels. First level (route), second
		// level subroute (action). The second level is mainly
		// used to select the view. First params is used to
		// select the controller action. If param does not exist.
		// Action is used as controller action else default action
		// is picked
		$this->route = $this->getRoute($route, $action);
		$model = $this->get('model');
		$this->controller = $this->get('controller', $model);
		$this->view = $this->get('view', $model);

		$this->setAction($action, $params)->setParams($params);
	}

	public function run() {

		if (!empty($this->action))
			$this->controller->{$this->action}($this->params);

		if (Request::IsAjax())
			header("Content-type: application/json");
		echo $this->view->render();
	}

	private function get($t, $p = null) {

		$n = $this->route->$t;
		return new $n($p);
	}

	private function getRoute($main, $sub = null) {

		$router = new Router();
		$route = $main . '.' . $sub;

		if (isset($router->$route))
			return $router->$route;

		$route = $main . '.' . Router::DEFAULT_SUBROUTE;

		if (isset($router->$route))
			return $router->$route;

		$route = Router::DEFAULT_MAINROUTE . '.' . Router::DEFAULT_SUBROUTE;

		return $router->$route;
	}

	private function setAction($action, &$params) {

		$this->action = $this->controller->getDefaultAction();

		$action = is_array($params)
			? array_shift($params)
			: $action;

		if (!empty($action)) {
			if (method_exists($this->controller, $action))
				$this->action = $action;
			else
				error_log("Controller action '$action' is not defined, fallback to '{$this->action}'.");
		}

		return $this;
	}

	private function setParams($params) {
		$this->params = $params;
		return $this;
	}
}