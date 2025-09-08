package;

import utest.ui.common.HeaderDisplayMode;
import utest.ui.Report;
import utest.Runner;
import cases.*;

class TestAll {
    public static function main() {
        var runner = new Runner();
        
        /*
        runner.addCase(new TestBasic());
        runner.addCase(new TestXPath());
        */
        runner.addCase(new TestPositionInfo());
        /*
        runner.addCase(new TestMalformed());
        */

        Report.create(runner, SuccessResultsDisplayMode.AlwaysShowSuccessResults, HeaderDisplayMode.NeverShowHeader);
        runner.run();
    }
}