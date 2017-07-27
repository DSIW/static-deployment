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

SOURCE_DIR = "src"
BUILD_DIR = "build"
CONFIG = JSON.parse(File.read(OPTIONS[:config]))
CSS_DIR = File.join(BUILD_DIR, CONFIG['css_dir'])
JS_DIR = File.join(BUILD_DIR, CONFIG['js_dir'])
PAGES = CONFIG['pages'].map { |p| File.join(BUILD_DIR, p) }
URL = CONFIG['urls'].fetch(OPTIONS[:env])

def run(cmd_string, options = {})
    # check if program exists
    components = Shellwords.split(cmd_string)
    program = components[0]
    `which #{program}`
    unless $?.success?
        abort("ERROR: Please install #{program} to continue!")
    end

    # Print message
    message = options[:message]
    if message.nil?
        puts ">> Running `#{cmd_string}`..."
    else
        puts ">> #{message}..." if message
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

def clone(source, target)
    run("rm -rf #{target}", message: 'Cleaning old build')
    run("cp -r #{source} #{target}", message: 'Cloning')
end

def minify_html
    PAGES.each do |page|
        basename = File.basename(page)
        run("minify --type=html -o #{BUILD_DIR}/#{basename} #{BUILD_DIR}/#{basename}", message: "Minify #{basename}")
    end
end

def change_pages(sed_string, options)
    run("sed -i -e '#{sed_string}' #{PAGES.join(' ')}", options)
end

def minify_asset(dir, basenames, ext)
    files = basenames.map { |basename| File.join(dir, basename) }
    minified = "#{dir}/min.#{ext}"
    run("minify -o #{minified} #{files.join(' ')}", message: 'Minify CSS')
    puts ">> Use MD5 hash for minified #{ext.upcase}..."
    md5 = run("md5sum #{minified}", message: false).chomp.split(/\s+/)[0]
    run("mv #{minified} #{File.join(BUILD_DIR, CONFIG['assets_dir'], "#{md5}.min.#{ext}")}", message: false)
    run("rm -rf #{dir}", message: false)
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

def upload
    run("rsync -avz --delete #{BUILD_DIR}/ #{File.join(CONFIG['remote'], URL)}", message: 'Uploading')
end

puts "Deploying to #{URL}..."
sleep 0.5
ask_for_commit
clone(SOURCE_DIR, BUILD_DIR)
minify_asset(CSS_DIR, CONFIG['css_files'], 'css')
run("rm -rf #{File.join(BUILD_DIR, CONFIG['assets_dir'], 'sass')}", message: 'Remove SASS files')
minify_asset(JS_DIR, CONFIG['js_files'], 'js')
# minify_html
minify_images(File.join(BUILD_DIR, CONFIG['images_dir']))
set_noindex if OPTIONS[:env] != 'production'
upload
puts "Successfully deployed."
