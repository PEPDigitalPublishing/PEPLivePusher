
Pod::Spec.new do |s|

    s.name            = 'PEPLivePusher'

    s.version         = '1.0.0'

    s.summary         = 'PEP直播推流器'

    s.license         = 'MIT'

    s.homepage        = 'https://github.com/PEPDigitalPublishing/PEPLivePusher'


    s.author          = { '崔冉' => 'cuir@pep.com.cn' }

    s.platform        = :ios, '9.0'

    s.source          = { :git => 'https://github.com/PEPDigitalPublishing/PEPLivePusher/trunk' }

    s.source_files    = 'PEPLivePusher/*.{h,m}'

    s.resources       = 'PEPLivePusher/PEPLivePusher.bundle'

    s.vendored_frameworks = 'AlivcLivePusher/AlivcLibRtmp.framework', 'AlivcLivePusher/AlivcLivePusher.framework'

    s.frameworks      = 'Foundation', 'UIKit'

end
