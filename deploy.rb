#!/usr/bin/env ruby
# encoding: utf-8

require 'json'
require 'shellwords'
require 'optparse'

OPTIONS = {config: 'deployment.json', dry_run: false, verbose: false}
OptionParser.new do |opts|
  opts.banner = "Usage: #{File.basename(__FILE__)} [options] [staging|production]"
  opts.banner << "\n"
  opts.banner << "\nOptimize assets and deploy your static website."
  opts.banner << "\n"
  opts.banner << "\nOptions:"

  opts.on("-c", "--config", "Config file (default: deployment.json)") do |v|
    OPTIONS[:dry_run] = v
  end
  opts.on("-n", "--[no-]dry-run", "Run without actions") do |v|
    OPTIONS[:dry_run] = v
  end
  opts.on("-v", "--[no-]verbose", "Run verbosely") do |v|
    OPTIONS[:verbose] = v
  end
end.parse!
OPTIONS[:env] = ARGV[0] || 'staging'

CONFIG = JSON.parse(File.read(OPTIONS[:config]))
URL = CONFIG['urls'].fetch(OPTIONS[:env])

module Utils
  def tool_present?(cmd_string)
    components = Shellwords.split(cmd_string)
    program = components[0]
    `which #{program}`
    $?.success?
  end

  def log(string)
    if OPTIONS[:verbose]
      puts string
    end
  end

  def run(cmd_string, options = {})
    unless tool_present?(cmd_string)
      abort("ERROR: Please install #{program} to continue!")
    end

    # Print message
    message = options[:message]
    if message.nil?
      log ">> Running `#{cmd_string}`..."
    else
      log(">> #{message}...") if message
    end

    # Run command
    output = OPTIONS[:dry_run] || `#{cmd_string}`
    abort("ERROR in execution of `#{cmd_string}`!") unless $?.success?

    output
  end

  def ask_for_commit
    dirty = `git status -s | grep -v '^??'`.split("\n").length > 0
    if dirty
      print "Do you want to commmit changes first? [yN] "
      if STDIN.gets.chomp =~ /y/i
        exit 1
      end
    end
  end
end

class Deployment
  include Utils

  def initialize(source_dir, build_dir)
    @source_dir = source_dir
    @build_dir = build_dir

    @git = tool_present?("git")
  end

  def deploy_to(url)
    log "Deploying to #{url}..."
    sleep 0.5
    ask_for_commit if @git
    clone
    minify_asset(css_dir, CONFIG['css_files'], 'css')
    run("rm -rf #{File.join(clone_dir, CONFIG['assets_dir'], 'sass')}", message: 'Remove SASS files')
    minify_asset(js_dir, CONFIG['js_files'], 'js')
    # minify_html
    minify_images(File.join(clone_dir, CONFIG['images_dir']))
    set_noindex if OPTIONS[:env] != 'production'
    upload(url)
    log "Successfully deployed."
  end

  def clone
    run("rm -rf #{@build_dir}", message: 'Cleaning old build')
    if @git
      run("git clone . #{@build_dir} 2>/dev/null", message: 'Cloning commited files')
    else
      run("cp -r #{@source_dir} #{@build_dir}", message: 'Copying files')
    end
  end

  private

  def minify_html
    pages.each do |page|
      basename = File.basename(page)
      run("minify --type=html -o #{clone_dir}/#{basename} #{clone_dir}/#{basename}", message: "Minify #{basename}")
    end
  end

  def minify_asset(dir, basenames, ext)
    files = basenames.map { |basename| File.join(dir, basename) }
    minified = "#{dir}/min.#{ext}"

    run("minify -o #{minified} #{files.join(' ')}", message: 'Minify CSS')

    log ">> Use MD5 hash for minified #{ext.upcase}..."
    if OPTIONS[:dry_run]
      md5 = 'dry-run'
    else
      md5 = run("md5sum #{minified}", message: false).chomp.split(/\s+/)[0]
    end
    run("mv #{minified} #{File.join(clone_dir, CONFIG['assets_dir'], "#{md5}.min.#{ext}")}", message: false)
    run("rm -rf #{dir}", message: false)

    # replace every asset reference with minified version
    files.each_with_index do |file, i|
      file = File.join(ext, File.basename(file))
      regex = Regexp.escape(file).gsub('/', '\/')
      last = i == files.length - 1
      if last
        change_pages("s/#{regex}/#{md5}.min.#{ext}/g", message: false)
      else
        change_pages("/#{regex}/d", message: false)
      end
    end
  end

  def minify_images(dir)
    run("jpegoptim --strip-all --all-progressive -m90 #{dir}/*.jpg", message: 'Optimize JPGs')
    run("optipng #{dir}/*.png 2>/dev/null", message: 'Optimize PNGs')
    # run("svgo -f #{dir}", message: 'Optimize SVGs')
  end

  def set_noindex
    message = "Set noindex and nofollow for #{OPTIONS[:env]} environment"
    change_pages("s/content=\".*index.*\"/content=\"noindex, nofollow\"/g", message: message)
  end

  def upload(url)
    run("rsync -avz --delete #{clone_dir}/ #{File.join(CONFIG['remote'], url)}", message: 'Uploading')
  end

  def change_pages(sed_string, options)
    run("sed -i -e '#{sed_string}' #{pages.join(' ')}", options)
  end

  def css_dir
    File.join(clone_dir, CONFIG['css_dir'])
  end

  def js_dir
    File.join(clone_dir, CONFIG['js_dir'])
  end

  def pages
    CONFIG['pages'].map { |p| File.join(clone_dir, p) }
  end

  def clone_dir
    @git ? File.join(@build_dir, @source_dir) : @build_dir
  end
end

Deployment.new("src", "build").deploy_to(URL)
