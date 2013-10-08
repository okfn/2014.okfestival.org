require 'wake/assets'

module Wake
  class Assets
    def generated_files
      files = Set.new
      [CSS, JS, IMG].each do |group|
        next unless @config[group]
        dirname = File.join(@pwd, @config[group]['targetDirectory'])
        manifest = File.join(dirname, MANIFEST)
        files << manifest
        files += @manifest[manifest].keys.map { |x| File.join(dirname, x) }
        files += @manifest[manifest].values.map { |x| File.join(dirname, x) }
      end
      files.to_a
    end
  end
end

def make_wake_assets(conf)
  wake_conf = conf['wake'] || {}
  @wake = Wake::Assets.new(
    :wake    => File.expand_path('node_modules/.bin/wake', conf['source']),
    :root    => conf['destination'],
    :mode    => wake_conf['mode'] || :targets,
    :monitor => wake_conf['monitor'] || false,
  )
end

module Jekyll

  class WakeAssetsFile < StaticFile
    def write(dest)
      # do nothing
    end
  end

  class WakeAssetsGenerator < Generator
    safe true
    priority :high

    def generate(site)
      @wake_cmd = File.expand_path('node_modules/.bin/wake', site.config['source'])

      # Run wake to build/compress the assets
      system(@wake_cmd)

      # Use wake's generated manifests to ensure that Jekyll doesn't blow away
      # the generated files.
      @wake = make_wake_assets(site.config)
      @dest_root = Pathname.new(site.config['destination'])
      @wake.generated_files.each do |path|
        relpath = Pathname.new(path).relative_path_from(@dest_root)
        site.static_files << WakeAssetsFile.new(site, site.source, relpath.dirname, relpath.basename)
      end
    end
  end

  class WakeAssetsTag < Liquid::Tag
    def initialize(tag_name, params, tokens)
      super
      @name = params.strip
    end

    def render(context)
      @wake = make_wake_assets(context.registers[:site].config)
      @renderer = @wake.renderer
    end
  end

  class WakeIncludeJsTag < WakeAssetsTag
    def render(context)
      super
      @renderer.include_js(@name)
    end
  end

  class WakeIncludeCssTag < WakeAssetsTag
    def render(context)
      super
      @renderer.include_css(@name)
    end
  end

  class WakeIncludeImageTag < WakeAssetsTag
    def render(context)
      super
      @renderer.include_image(@name)
    end
  end

  class WakeUrlForImageTag < WakeAssetsTag
    def render(context)
      super
      # This is a bit nasty, as it could be multiple URLs...
      urls = @renderer.urls_for(Wake::Assets::IMG, [@name])
      urls * ''
    end
  end
end

Liquid::Template.register_tag('include_js', Jekyll::WakeIncludeJsTag)
Liquid::Template.register_tag('include_css', Jekyll::WakeIncludeCssTag)
Liquid::Template.register_tag('include_image', Jekyll::WakeIncludeImageTag)
Liquid::Template.register_tag('url_for_image', Jekyll::WakeUrlForImageTag)
