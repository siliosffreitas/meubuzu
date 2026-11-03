import 'package:vaden/vaden.dart';

@Controller('/hello')
class HelloController {
  @Get('/')
  String hello() {
    return 'hello';
  }

  @Get('/ping')
  String ping() {
    return 'pong';
  }
}

