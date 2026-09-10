# Angular

Standalone component (Angular 17+):

```ts
import { Component, Input, computed, signal } from "@angular/core";
import { tokenize, type SmoothOptions, type Token } from "@smooth-reading/core";

@Component({
  selector: "smooth-text",
  standalone: true,
  template: `
    @for (t of tokens(); track $index) {
      @if (t.type === "word") {
        <span><span class="sr-fixation">{{ t.fixationText }}</span><span class="sr-rest">{{ t.restText }}</span></span>
      } @else {{{ t.text }}}
    }
  `,
})
export class SmoothTextComponent {
  private readonly text$ = signal("");
  private readonly options$ = signal<SmoothOptions>({});
  @Input() set text(v: string) { this.text$.set(v); }
  @Input() set options(v: SmoothOptions) { this.options$.set(v); }
  readonly tokens = computed<Token[]>(() => tokenize(this.text$(), this.options$()));
}
```

Directive for existing DOM:

```ts
import { Directive, ElementRef, Input, OnChanges, OnDestroy } from "@angular/core";
import { applyToElement, type SmoothOptions } from "@smooth-reading/core";

@Directive({ selector: "[smooth]", standalone: true })
export class SmoothDirective implements OnChanges, OnDestroy {
  @Input("smooth") options: SmoothOptions = {};
  private restore?: () => void;
  constructor(private el: ElementRef<HTMLElement>) {}
  ngOnChanges() { this.restore?.(); this.restore = applyToElement(this.el.nativeElement, this.options); }
  ngOnDestroy() { this.restore?.(); }
}
```
