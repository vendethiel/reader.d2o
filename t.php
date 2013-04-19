<?php
foreach (glob('data/*.d2o') as $f)
	system('lsc index.ls ' . substr($f, 5, -4));