import 'package:smooth_reading/smooth_reading.dart';
import 'package:test/test.dart';

void main() {
  group('toHtml', () {
    test('wraps fixations in <b> by default', () {
      expect(toHtml('Smooth reading works.'),
          '<b>Smo</b>oth <b>read</b>ing <b>wor</b>ks.');
    });

    test('supports tag, class names and a rest tag', () {
      expect(
        toHtml(
          'Smooth reading',
          tag: 'span',
          className: 'sr-fixation',
          restTag: 'span',
          restClassName: 'sr-rest',
        ),
        '<span class="sr-fixation">Smo</span><span class="sr-rest">oth</span> '
        '<span class="sr-fixation">read</span><span class="sr-rest">ing</span>',
      );
    });

    test('omits an empty rest element for fully emphasised words', () {
      expect(toHtml('a', restTag: 'span'), '<b>a</b>');
    });

    test('escapes text but not existing markup', () {
      expect(
        toHtml('<p>Smooth reading</p> <code>x = 1</code> <b>done</b> & gone'),
        '<p><b>Smo</b>oth <b>read</b>ing</p> <code>x = 1</code> <b>done</b> '
        '&amp; <b>go</b>ne',
      );
    });

    test('character references pass through and act as word boundaries', () {
      expect(toHtml('rock&amp;roll'), '<b>ro</b>ck&amp;<b>ro</b>ll');
      expect(toHtml('a &#x27; b'), '<b>a</b> &#x27; <b>b</b>');
    });

    test('bare ampersands and stray angle brackets are escaped', () {
      expect(toHtml('Tom & Jerry <3'), '<b>To</b>m &amp; <b>Jer</b>ry &lt;3');
      expect(toHtml('1 < 2'), '1 &lt; 2');
    });

    test('ignoreHtmlTags false escapes everything', () {
      expect(toHtml('<b>hi</b>', ignoreHtmlTags: false),
          '&lt;<b>b</b>&gt;<b>h</b>i&lt;/<b>b</b>&gt;');
    });

    test('skips nested same-named skip tags and self-closing tags', () {
      expect(toHtml('<pre><pre>keep this</pre>and this</pre> done'),
          '<pre><pre>keep this</pre>and this</pre> <b>do</b>ne');
      expect(toHtml('line<br/>break'), '<b>li</b>ne<br/><b>bre</b>ak');
    });

    test('tag names follow the HTML grammar, like the TypeScript core', () {
      // The name runs to whitespace, `/` or `>`: `code.x` is not `code`.
      expect(toHtml('<code.x>hello</code.x>'), '<code.x><b>hel</b>lo</code.x>');
      // Whitespace is allowed around the closing slash.
      expect(toHtml('<code>x y</ code> ok'), '<code>x y</ code> <b>o</b>k');
      // A space before the closing slash still self-closes.
      expect(toHtml('<code / > x y'), '<code / > <b>x</b> <b>y</b>');
      // `</>` and `<3` are not tags that change skip state.
      expect(toHtml('a </> b <3'), '<b>a</b> </> <b>b</b> &lt;3');
    });

    test('tag names are matched case-insensitively', () {
      expect(toHtml('<CODE>x y</CODE> ok'), '<CODE>x y</CODE> <b>o</b>k');
    });

    test('custom skipTags replace the defaults', () {
      expect(toHtml('<code>x y</code> <em>ok</em>', skipTags: ['em']),
          '<code><b>x</b> <b>y</b></code> <em>ok</em>');
    });

    test('never nests the emphasis tag', () {
      expect(toHtml('<b>already</b> bold'), '<b>already</b> <b>bo</b>ld');
      expect(toHtml('<span>x</span> y', tag: 'span'),
          '<span>x</span> <span>y</span>');
    });

    test('saccade counting continues across markup and skips skip tags', () {
      const options = SmoothOptions(saccade: 2);
      expect(toHtml('one <i>two</i> three', options: options),
          '<b>on</b>e <i>two</i> <b>thr</b>ee');
      expect(toHtml('one <code>two</code> three', options: options),
          '<b>on</b>e <code>two</code> three');
    });

    test('comments, CDATA and processing instructions pass through', () {
      expect(toHtml('<!-- a b --> c'), '<!-- a b --> <b>c</b>');
      expect(toHtml('<![CDATA[a b]]> c'), '<![CDATA[a b]]> <b>c</b>');
      expect(toHtml('<!DOCTYPE html> c'), '<!DOCTYPE html> <b>c</b>');
    });

    test('escapes class names', () {
      expect(toHtml('a', className: 'x"y'), '<b class="x&quot;y">a</b>');
    });
  });

  group('toMarkdown', () {
    test('wraps fixations in the marker without escaping', () {
      expect(toMarkdown('Smooth reading works.'),
          '**Smo**oth **read**ing **wor**ks.');
      expect(toMarkdown('a & b', marker: '__'), '__a__ & __b__');
    });
  });

  test('escapeHtml escapes exactly & < > "', () {
    expect(escapeHtml('<a href="x">&\'</a>'),
        '&lt;a href=&quot;x&quot;&gt;&amp;\'&lt;/a&gt;');
  });
}
