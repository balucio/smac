   <?php

class GenericController {

    public
        $action,
        $status
    ;

    private
        $models = null
    ;

    public function __construct($model) {

        $this->model = $model;
        $model->initData();
    }
}