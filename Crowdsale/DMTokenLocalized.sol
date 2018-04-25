pragma solidity ^0.4.21;

import "zeppelin-solidity/contracts/AddressUtils.sol";
import "zeppelin-solidity/contracts/lifecycle/Pausable.sol";
import "zeppelin-solidity/contracts/math/SafeMath.sol";

/**
 * Токен для Imaguru Blockchain Hackathon
 * DebtMoneyToken  - информация, полученная в результате вычислений
 * о наличии замкнутого цикла графа клиентов
 * Токен локазирован под использование в РБ
 */
contract DMTokenLocalized is Pausable {

	using AddressUtils for address;
	using SafeMath for uint256;

	// Вызывается, когда добавляется новая 
	event LoanAdded(uint256 amountOfCompanies, uint256 indexed amount, uint8 indexed cur);

	// Вызывается, когда цепочка погашается
	event LoanBurned(uint256 loanIndex);

	// Вызывается, когда поступило новое подтверждение
	event NewAcceptReceived(uint256 loadIndex, uint256 numberOfAccepts); 

	// Вызывается, когда назначается новый администратор
	event AdminTransfered(address from, address to);

	// Ethereum адрес сервера, с которого могут приходить запросы на добавление новых токенов
	address public serverAddress;

	// Адрес администратора контракта
	address public admin;

	// Структура для задолженности
	struct Loan {
		// Ссылка на данные о задолженности, которые хранятся в блокчейне голоса
		string link;
		// Сумма задолженности на основании количества участников и размере минимального плеча
		uint256 amount;
		// Валюта задолженности 1 - USD, 2 - EUR, 3 - RUB, 4 - BYN
		uint8 currency;
		// Количество компаний в цепочке
		uint256 amountOfCompanies;
		// Количество подтверждений
		uint256 amountOfAccepts;
		// Можно ли выкупить цепочку
		bool isReady;
		// Контракт погашен
		bool isBurned;
		// Дата создания
		uint256 date;
	}

	// Массив задолженностей
	Loan[] loans;

	// Массив владельцев задолженностей
	// Сюда заносятся адреса, которые приобрели конкретную цепочку задолженностей
	mapping(address => uint256) public owners;
	// Отображается кому принадлежит конкретная цепочка
	mapping(uint256 => address) public ownerOf;

	modifier onlyServer() {
		require(msg.sender == serverAddress);
		_;
	}

	modifier onlyAdmin() {
		require(msg.sender == admin);
		_;
	}

	// Создатель контракта считается его администратором
	function DMToken() public {
		admin = msg.sender;
	}

	// Передает право управления
	function transferAdminship(address _to) public onlyAdmin {
		require(_to != address(0));
		admin = _to;
	}

	// Назначает новый адрес сервера
	function setServerAddress(address _server) public onlyAdmin {
		require(_server != address(0));
		// Контракт не может быть сервером
		require(!_server.isContract());
		serverAddress = _server;
	}

	/**
	 * Добавляет новую цепочку задолженностей в список
	 * @param _link Ссылка на информацию о задолженности
	 * @param _amount Размер минимального плеча
	 * @param _companies Количество компаний в цепочке
	 * @param _currency Код валюты, указано в struct Loan
	 */
	function addLoan(string _link, uint256 _amount, uint256 _companies, uint8 _currency) public onlyServer whenNotPaused {
		require(_amount > 0);
		require(_companies > 0);
		Loan memory loan = Loan(_link, _amount * _companies, _currency, _companies, 0, false, false, now);
		loans.push(loan);
		emit LoanAdded(_companies, _amount, _currency);
	}

	/**
	 * Вызывается, для погашения цепочки задолженностей
	 * @param _index Индекс цепочки в массиве
	 * TODO: Подумать удалять ли контракт из массива или оставлять его
	 */
	function burnLoan(uint256 _index) public whenNotPaused {
		// Только владелец цепочки может сжечь ее
		require(owners[msg.sender] == _index);
		// Для того, чтобы сжечь цепочку. она должна быть валидной
		require(loans[_index].amountOfAccepts == loans[_index].amountOfCompanies);
		// Можно сжечь только существующую цепочку
		require(isExists(_index));

		loans[_index].isBurned = true;
		emit LoanBurned(_index);
	}

	/**
	 * Вызывается для подтверждения наличия задолженности от предприятия
	 */
	function acceptLoan(uint256 _index) public onlyServer whenNotPaused {
		require(isExists(_index));
		require(!loans[_index].isReady);
		require(loans[_index].amountOfAccepts + 1 <= loans[_index].amountOfCompanies);

		loans[_index].amountOfAccepts++;
		emit NewAcceptReceived(_index, loans[_index].amountOfAccepts);

		if (loans[_index].amountOfCompanies == loans[_index].amountOfAccepts) {
			loans[_index].isReady = true;
		}
	}

	/**
	 * Проверяет существование цепочки задолженностей по ее индексу
	 * Данная проверка работает на основании того, что не может существовать нулевой долг
	 * @param _index Индекс контракта
	 */ 
	function isExists(uint256 _index) view internal returns (bool) {
		return loans[_index].amount != 0;
	}

	/**
	 * Проверяет, погашена ли цепочка задолженностей
	 * @param _index Индекс контракта
	 */ 
	function isBurned(uint256 _index) view internal returns (bool) {
		return loans[_index].isBurned;
	}

	// Возвращает процентную ставку по каждой из цепочек
	function getPercentage(uint256 _index) view internal returns (uint8) {
		require(isExists(_index));
		uint256 hoursDifference = (now - loans[_index].date) % 3600000;
		if (hoursDifference < 2) {
			return 1;
		} else if (hoursDifference < 4) {
			return 3;
		} else {
			return 5;
		}
	}

	// Возвращает цену указанного токена
	function calcPrice(uint256 _index) public view returns (uint256) {
		require(isExists(_index));
		uint256 price = loans[_index].amount.mul(100+getPercentage(_index)).div(100);
		return price;
	}
}