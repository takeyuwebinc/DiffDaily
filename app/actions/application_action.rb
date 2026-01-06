class ApplicationAction
  # Actionの基底クラス
  # 各Actionは perform メソッドを実装する
  # クラスメソッドとして .perform を呼び出せる

  def self.perform(*args, **kwargs, &block)
    new(*args, **kwargs).perform(&block)
  end

  def perform
    raise NotImplementedError, "#{self.class}#perform must be implemented"
  end
end
