Pod::Spec.new do |s|
	# custom pod stuffs here
	s.name		= 'AHDispatch'
	s.version	= '0.9.1'
	s.summary 	= 'Queue throttling functionality for GCD'
	s.homepage 	= 'https://github.com/rayascott/AHDispatch'
	s.license  	= 'MIT'
	s.author 	= {
		'Ray Scott' => 'ray@alienhitcher.com'
	}
	s.source 	= {
		:git => 'https://github.com/rayascott/AHDispatch.git',
		:tag => s.version.to_s
	}
	s.source_files = 'AHDispatch/*.{h,m}'
    s.requires_arc = true
	s.ios.deployment_target = '6.0'
  	s.osx.deployment_target = '10.8'
end
