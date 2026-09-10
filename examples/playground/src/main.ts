import { toHtml, type Fixation } from '@smooth-reading/core';
import '@smooth-reading/core/styles.css';
import './style.css';

const SAMPLE = [
  'Smooth reading emphasises the first part of every word so the eye has an artificial fixation point and the brain completes the rest. It works on plain text, on existing HTML, and on streams — and the output is identical in every port of the library.',
  '平滑阅读会强调每个词的开头部分，让眼睛有一个人工的注视点，其余部分由大脑自动补全。它使用 Intl.Segmenter 进行分词，因此中文、日文和泰文都能正确处理。',
  'การอ่านแบบเน้นจุดจับตาจะเน้นส่วนต้นของแต่ละคำ เพื่อให้ดวงตามีจุดโฟกัสเทียมและสมองเติมส่วนที่เหลือให้เอง ภาษาไทยไม่มีช่องว่างระหว่างคำ จึงต้องอาศัยพจนานุกรมในการตัดคำ',
].join('\n\n');

function byId<T extends HTMLElement>(id: string): T {
  const el = document.getElementById(id);
  if (!el) throw new Error(`missing #${id}`);
  return el as T;
}

const input = byId<HTMLTextAreaElement>('input');
const preview = byId<HTMLElement>('preview');
const fixation = byId<HTMLInputElement>('fixation');
const saccade = byId<HTMLInputElement>('saccade');
const opacity = byId<HTMLInputElement>('opacity');
const fixationOut = byId<HTMLOutputElement>('fixation-out');
const saccadeOut = byId<HTMLOutputElement>('saccade-out');
const opacityOut = byId<HTMLOutputElement>('opacity-out');

input.value = SAMPLE;

function render(): void {
  const strength = Number(fixation.value) as Fixation;
  const every = Number(saccade.value);
  fixationOut.value = String(strength);
  saccadeOut.value = String(every);

  // The textarea holds plain text, so escape everything (`ignoreHtmlTags: false`)
  // and render one <p> per blank-line-separated paragraph.
  const html = input.value
    .split(/\n{2,}/)
    .map(
      (paragraph) =>
        `<p>${toHtml(paragraph, {
          fixation: strength,
          saccade: every,
          ignoreHtmlTags: false,
          tag: 'span',
          className: 'sr-fixation',
          restTag: 'span',
          restClassName: 'sr-rest',
        })}</p>`,
    )
    .join('');
  // Safe: every character of user text was escaped by toHtml above; the only
  // markup is the <p> and <span> elements this file builds itself.
  preview.innerHTML = html;
}

function updateOpacity(): void {
  const value = Number(opacity.value);
  opacityOut.value = value.toFixed(2);
  preview.style.setProperty('--sr-rest-opacity', String(value));
}

input.addEventListener('input', render);
fixation.addEventListener('input', render);
saccade.addEventListener('input', render);
opacity.addEventListener('input', updateOpacity);

render();
updateOpacity();
