![logo](logo.png)

Optimize assets and deploy your static website.

## Features

* Use only commited files
* Minify CSS and use MD5 hash as file name
* Minify JS and use MD5 hash as file name
* Optimize images (JPG, PNG)
* Set noindex and nofollow for non production environment

Example output:

```
$ ./deploy.rb -v

Deploying to staging.example.com...
Do you want to commmit changes first? [yN] n
>> Cleaning old build...
>> Cloning commited files...
>> Minify CSS...
>> Use MD5 hash for minified CSS...
>> Remove SASS files...
>> Minify CSS...
>> Use MD5 hash for minified JS...
>> Optimize JPGs...
>> Optimize PNGs...
>> Set noindex and nofollow for staging environment...
>> Uploading...
Successfully deployed.
```

## Dependencies

Some system tools are needed:

* `minify` for minifying your assets
* `md5sum` for generating md5 hashes of your assets
* `sed` for changing your HTML files for the optimized assets
* `jpgoptim` for optimizing your JPG files (progress, 90%)
* `optipng` for optimizing your PNG files
* `rsync` for uploading to your server

## Installation

1. Install ruby
1. Install dependencies
1. Clone `git clone https://github.com/DSIW/swd.git`
1. Put `deployment.json` and `deploy.rb` in your project directory
1. Make changes in `deployment.json`

## Usage

```
$ deploy.rb --help

Usage: deploy.rb [options] [staging|production]

Optimize assets and deploy your static website.

Options:
    -c, --config                     Config file (default: deployment.json)
    -n, --[no-]dry-run               Run without actions
    -v, --[no-]verbose               Run verbosely
```

### Project structure

The following project structure is needed.

```
project/
  src/
    assets/
        css/
        js/
        images/
    index.html
  build/
    ...
```

Note: Maybe some other improvements of your site are recommended:

* [Activate compression](https://developers.google.com/speed/docs/insights/EnableCompression) on Server for HTML, SVG,... files.
* [Use browser caching](https://developers.google.com/speed/docs/insights/LeverageBrowserCaching)
* Set the robots meta tag if you like. [The robots.txt will be ignored if your site is linked.](https://support.google.com/webmasters/answer/6062608)
* Set favicon using [Favicon Generator](https://favicon.il.ly)

## TODO

Some additional features would be nice:

- [x] Use only commited files for the deployment
- [ ] Parse CSS, JS and images folder from HTML files
- [ ] Deploy to gh-pages

Contribution is very welcome! Create an issue or pull request!

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b feature-[short_description]` or `git checkout -b fix-[github_issue_number]-[short_description]`)
3. Commit your changes (`git commit -am 'Add some missing feature'`)
4. Push to the branch (`git push origin [branch-name]`)
5. Create new Pull Request

## License

MIT License

Copyright (c) 2017 DSIW

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
