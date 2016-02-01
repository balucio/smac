   <?php

class GenericController {

    private
        $models = null
    ;

    public function __construct($model) {

        $this->model = $model;
        $model->initData();
    }
}