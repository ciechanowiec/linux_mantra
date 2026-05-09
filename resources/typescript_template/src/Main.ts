import { SamplePrinter } from "./SamplePrinter.js";

const printer: SamplePrinter = new SamplePrinter("Hello, Universe!");
const lines: ReadonlyArray<string> = await printer.getLines();
for (const line of lines) {
    console.info(line);
}
